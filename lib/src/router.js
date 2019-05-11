import pathToRegexp from 'path-to-regexp';
import { Linking } from 'react-native';
import { Navigator } from './Navigator';
function routeDependencies(routeConfig) {
    let dependencies = [];
    let config = routeConfig;
    while (config && config.dependency) {
        dependencies.push(config.dependency);
        config = configs.get(config.dependency);
    }
    return dependencies.reverse();
}
const stackParser = {
    navigateTo(_, graph, route) {
        const { layout, children } = graph;
        const { mode, moduleName, dependencies, props } = route;
        if (layout === 'stack' && mode === 'push') {
            let moduleNames = [...dependencies, moduleName];
            let index = -1;
            for (let i = children.length - 1; i > -1; i--) {
                const { layout, moduleName } = children[i];
                if (layout === 'screen') {
                    index = moduleNames.indexOf(moduleName);
                    if (index !== -1) {
                        break;
                    }
                }
            }
            if (index !== -1) {
                let peddingModuleNames = moduleNames.slice(index + 1);
                const navigator = new Navigator(children[children.length - 1].sceneId);
                if (peddingModuleNames.length === 0) {
                    navigator.replace(moduleName, props);
                }
                else {
                    for (let i = 0; i < peddingModuleNames.length; i++) {
                        if (i === peddingModuleNames.length - 1) {
                            navigator.push(moduleName, props);
                        }
                        else {
                            navigator.push(peddingModuleNames[i], {}, {}, false);
                        }
                    }
                }
                return true;
            }
        }
        return false;
    },
};
const tabsParser = {
    navigateTo(router, graph, route) {
        const { layout, children, selectedIndex } = graph;
        if (layout === 'tabs') {
            for (let i = 0; i < children.length; i++) {
                if (router.navigateTo(children[i], route)) {
                    if (i !== selectedIndex) {
                        const navigator = new Navigator(children[i].sceneId);
                        navigator.switchTab(i);
                    }
                    return true;
                }
            }
        }
        return false;
    },
};
const drawerParser = {
    navigateTo(router, graph, route) {
        const { layout, children } = graph;
        if (layout === 'drawer') {
            if (router.navigateTo(children[0], route) || router.navigateTo(children[1], route)) {
                const navigator = new Navigator(children[0].sceneId);
                navigator.closeMenu();
                return true;
            }
            const { moduleName } = children[1];
            if (moduleName === route.moduleName) {
                const navigator = new Navigator(children[1].sceneId);
                navigator.openMenu();
                return true;
            }
        }
        return false;
    },
};
let configs = new Map();
let interceptors = new Set();
let active = 0;
let parsers = new Set([drawerParser, tabsParser, stackParser]);
class Router {
    constructor() {
        this.routeEventHandler = this.routeEventHandler.bind(this);
        this.hasHandleInitialURL = false;
    }
    clear() {
        active = 0;
        configs.clear();
    }
    addRouteConfig(moduleName, routeConfig) {
        if (routeConfig.path) {
            routeConfig.pathRegexp = pathToRegexp(routeConfig.path);
            let params = pathToRegexp.parse(routeConfig.path).slice(1);
            routeConfig.paramNames = [];
            for (let i = 0; i < params.length; i++) {
                const key = params[i];
                routeConfig.paramNames.push(key.name);
            }
        }
        routeConfig.moduleName = moduleName;
        routeConfig.mode = routeConfig.mode || 'push';
        configs.set(moduleName, routeConfig);
    }
    registerInterceptor(func) {
        interceptors.add(func);
    }
    unregisterInterceptor(func) {
        interceptors.delete(func);
    }
    registerParser(parser) {
        parsers.add(parser);
    }
    pathToRoute(path) {
        for (const routeConfig of configs.values()) {
            if (!routeConfig.pathRegexp) {
                continue;
            }
            const match = routeConfig.pathRegexp.exec(path);
            if (match) {
                const moduleName = routeConfig.moduleName;
                if (!moduleName) {
                    return null;
                }
                const props = {};
                const names = routeConfig.paramNames;
                if (names) {
                    for (let i = 0; i < names.length; i++) {
                        props[names[i]] = match[i + 1];
                    }
                }
                const dependencies = routeDependencies(routeConfig);
                const mode = routeConfig.mode || 'push';
                return { moduleName, props, dependencies, mode };
            }
        }
        return null;
    }
    navigateTo(graph, route) {
        for (let parser of parsers.values()) {
            if (parser.navigateTo(this, graph, route)) {
                return true;
            }
        }
        return false;
    }
    async open(path) {
        if (!path) {
            return;
        }
        let intercepted = false;
        for (let interceptor of interceptors.values()) {
            intercepted = interceptor(path);
            if (intercepted) {
                return;
            }
        }
        const route = this.pathToRoute(path);
        if (!route) {
            return;
        }
        const graphArray = await Navigator.routeGraph();
        if (!graphArray) {
            return;
        }
        if (graphArray.length > 1) {
            for (let index = graphArray.length - 1; index > 0; index--) {
                const { mode: layoutMode } = graphArray[index];
                const navigator = await Navigator.current();
                if (!navigator) {
                    return;
                }
                if (layoutMode === 'present') {
                    navigator.dismiss();
                }
                else if (layoutMode === 'modal') {
                    navigator.hideModal();
                }
                else {
                    console.warn('尚未处理的 layout mode:' + layoutMode);
                }
            }
        }
        if (!this.navigateTo(graphArray[0], route)) {
            const navigator = await Navigator.current();
            if (!navigator) {
                return;
            }
            navigator.closeMenu();
            const { moduleName, mode: routeMode, props } = route;
            if (routeMode === 'present') {
                navigator.present(moduleName, 0, props);
            }
            else if (routeMode === 'modal') {
                navigator.showModal(moduleName, 0, props);
            }
            else {
                // default push
                navigator.push(moduleName, props);
            }
        }
    }
    activate(uriPrefix) {
        if (!uriPrefix) {
            throw new Error('must pass `uriPrefix` when activate router.');
        }
        if (active == 0) {
            this.uriPrefix = uriPrefix;
            if (!this.hasHandleInitialURL) {
                this.hasHandleInitialURL = true;
                Linking.getInitialURL()
                    .then(url => {
                    if (url) {
                        const path = url.replace(this.uriPrefix, '');
                        this.open(path);
                    }
                })
                    .catch(err => console.error('An error occurred', err));
            }
            Linking.addEventListener('url', this.routeEventHandler);
        }
        active++;
    }
    inactivate() {
        active--;
        if (active == 0) {
            Linking.removeEventListener('url', this.routeEventHandler);
        }
        if (active < 0) {
            active = 0;
        }
    }
    routeEventHandler(event) {
        console.info(`deeplink:${event.url}`);
        const path = event.url.replace(this.uriPrefix, '');
        this.open(path);
    }
}
const router = new Router();
export { router };