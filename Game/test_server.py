# from https://stackoverflow.com/questions/42341039/remove-cache-in-a-python-http-server
import http.server

PORT = 8000

class NoCacheHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # Set cache control headers
        self.send_header('Cache-Control', 'no-store, must-revalidate')
        self.send_header('Expires', '0')
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        
        # Set the correct MIME type for JavaScript files
        if self.path.endswith('.js'):
            self.send_header('Content-Type', 'application/javascript')
        
        super().end_headers()

if __name__ == '__main__':
    http.server.test(HandlerClass=NoCacheHTTPRequestHandler, port=PORT)
