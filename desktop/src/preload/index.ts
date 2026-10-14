import { contextBridge, ipcRenderer, type IpcRendererEvent } from 'electron'
import {
  IpcChannels,
  type AppInfo,
  type MenuCommand,
  type NduBridge,
  type WebAppState
} from '../shared/ipc'

/**
 * The only surface the renderer gets. `ipcRenderer` itself is never exposed —
 * the renderer cannot send on arbitrary channels, only these four operations.
 */
const bridge: NduBridge = {
  getAppInfo: () => ipcRenderer.invoke(IpcChannels.appInfo) as Promise<AppInfo>,

  openExternal: (url: string) =>
    ipcRenderer.invoke(IpcChannels.openExternal, url) as Promise<boolean>,

  reportState: (state: WebAppState, detail?: string) => {
    ipcRenderer.send(IpcChannels.webAppState, state, detail)
  },

  onMenuCommand: (listener: (command: MenuCommand) => void) => {
    const handler = (_event: IpcRendererEvent, command: MenuCommand) => listener(command)
    ipcRenderer.on(IpcChannels.menuCommand, handler)
    return () => {
      ipcRenderer.removeListener(IpcChannels.menuCommand, handler)
    }
  }
}

contextBridge.exposeInMainWorld('ndu', bridge)
