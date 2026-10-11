import { Menu, app, shell, type MenuItemConstructorOptions } from 'electron'
import type { MenuCommand } from '../shared/ipc'

export const DOCS_URL = 'https://staging.nduproject.com'
export const SUPPORT_URL = 'https://github.com'

interface MenuOptions {
  /** Called on the main thread when a menu item maps to a shell action. */
  onCommand: (command: MenuCommand) => void
}

/**
 * Builds the native menu bar.
 *
 * Menu items never touch the embedded app directly — they emit a
 * [MenuCommand] that the renderer applies to the `<webview>`. That keeps a
 * single place (the renderer) that knows how to drive the app, and means menu
 * state is unaffected by which page the user is on.
 */
export function buildAppMenu({ onCommand }: MenuOptions): Menu {
  const isMac = process.platform === 'darwin'

  const appMenu: MenuItemConstructorOptions[] = isMac
    ? [
        {
          label: app.name,
          submenu: [
            { role: 'about', label: `About ${app.name}` },
            { type: 'separator' },
            {
              label: 'Go to Sign In',
              accelerator: 'CmdOrCtrl+Shift+L',
              click: () => onCommand({ type: 'navigate', route: '/sign-in' })
            },
            { type: 'separator' },
            { role: 'services' },
            { type: 'separator' },
            { role: 'hide' },
            { role: 'hideOthers' },
            { role: 'unhide' },
            { type: 'separator' },
            { role: 'quit' }
          ]
        }
      ]
    : []

  const fileMenu: MenuItemConstructorOptions = {
    label: 'File',
    submenu: [
      ...(isMac
        ? []
        : [
            {
              label: 'Go to Sign In',
              accelerator: 'CmdOrCtrl+Shift+L',
              click: () => onCommand({ type: 'navigate', route: '/sign-in' })
            } as MenuItemConstructorOptions
          ]),
      {
        label: 'Open NDU Project in Browser',
        accelerator: 'CmdOrCtrl+Shift+O',
        click: () => onCommand({ type: 'open-in-browser' })
      },
      { type: 'separator' },
      isMac ? { role: 'close' } : { role: 'quit' }
    ]
  }

  const viewMenu: MenuItemConstructorOptions = {
    label: 'View',
    submenu: [
      {
        label: 'Reload App',
        accelerator: 'CmdOrCtrl+R',
        click: () => onCommand({ type: 'reload' })
      },
      {
        label: 'Reload App (Ignore Cache)',
        accelerator: 'CmdOrCtrl+Shift+R',
        click: () => onCommand({ type: 'hard-reload' })
      },
      { type: 'separator' },
      // Zoom is applied to the embedded app, so these deliberately replace the
      // built-in roles: a role would zoom the React shell instead of the
      // `<webview>` the user is actually looking at.
      {
        label: 'Actual Size',
        accelerator: 'CmdOrCtrl+0',
        click: () => onCommand({ type: 'zoom', direction: 'reset' })
      },
      {
        label: 'Zoom In',
        accelerator: 'CmdOrCtrl+Plus',
        click: () => onCommand({ type: 'zoom', direction: 'in' })
      },
      {
        label: 'Zoom Out',
        accelerator: 'CmdOrCtrl+-',
        click: () => onCommand({ type: 'zoom', direction: 'out' })
      },
      { type: 'separator' },
      { role: 'togglefullscreen' },
      {
        label: 'Toggle Developer Tools',
        accelerator: isMac ? 'Alt+Cmd+I' : 'Ctrl+Shift+I',
        click: () => onCommand({ type: 'toggle-devtools' })
      }
    ]
  }

  const editMenu: MenuItemConstructorOptions = {
    label: 'Edit',
    submenu: [
      { role: 'undo' },
      { role: 'redo' },
      { type: 'separator' },
      { role: 'cut' },
      { role: 'copy' },
      { role: 'paste' },
      ...(isMac
        ? ([
            { role: 'pasteAndMatchStyle' },
            { role: 'delete' },
            { role: 'selectAll' }
          ] as MenuItemConstructorOptions[])
        : ([
            { role: 'delete' },
            { type: 'separator' },
            { role: 'selectAll' }
          ] as MenuItemConstructorOptions[]))
    ]
  }

  const helpMenu: MenuItemConstructorOptions = {
    role: 'help',
    submenu: [
      {
        label: 'Open Documentation',
        click: () => void shell.openExternal(DOCS_URL)
      },
      {
        label: 'Report an Issue',
        click: () => void shell.openExternal(SUPPORT_URL)
      }
    ]
  }

  const template: MenuItemConstructorOptions[] = [
    ...appMenu,
    fileMenu,
    editMenu,
    viewMenu,
    { role: 'windowMenu' },
    helpMenu
  ]

  return Menu.buildFromTemplate(template)
}
