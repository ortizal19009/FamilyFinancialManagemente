export default {
  '/api': {
    target: 'http://127.0.0.1:5000',
    secure: false,
    changeOrigin: true,
    configure: (proxy) => {
      proxy.on('proxyReq', (_proxyReq, req) => {
        console.log(`[proxy] ${req.method} ${req.url}`);
      });
      proxy.on('proxyRes', (proxyRes, req) => {
        console.log(`[proxy] ${req.method} ${req.url} -> ${proxyRes.statusCode}`);
      });
    }
  },
  '/health': {
    target: 'http://127.0.0.1:5000',
    secure: false,
    changeOrigin: true
  }
};
