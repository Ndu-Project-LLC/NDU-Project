import { createRoot } from 'react-dom/client'
import App from './App'
import './styles.css'

const container = document.getElementById('root')
if (!container) {
  throw new Error('Renderer root element is missing')
}

// Deliberately not wrapped in <StrictMode>: its double-invoked effects would
// mount the <webview> twice in development, booting the whole Flutter
// application (and its 16 MB main.dart.js) a second time on every reload.
createRoot(container).render(<App />)
