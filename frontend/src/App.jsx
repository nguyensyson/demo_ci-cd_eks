import { useState } from 'react';
import { callBackend } from './config.js';
import './App.css';

function App() {
  const [response, setResponse] = useState(null);
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(false);

  const handleCallBackend = async () => {
    setLoading(true);
    setError(null);
    setResponse(null);

    try {
      const data = await callBackend();
      setResponse(data);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="container">
      <header className="header">
        <h1>🚀 Demo EKS Frontend</h1>
        <p>Microservice demo - Frontend calls Backend via Ingress</p>
      </header>

      <main className="main">
        <button
          className="call-button"
          onClick={handleCallBackend}
          disabled={loading}
        >
          {loading ? 'Calling...' : 'Call Backend'}
        </button>

        {error && (
          <div className="error-box">
            <strong>Error:</strong> {error}
          </div>
        )}

        {response && (
          <div className="response-box">
            <h2>Response from Backend:</h2>
            <pre>{JSON.stringify(response, null, 2)}</pre>
            <p className="hostname">
              <strong>Pod Hostname:</strong> {response.hostname}
            </p>
            <p className="timestamp">
              <strong>Timestamp:</strong> {response.timestamp}
            </p>
          </div>
        )}
      </main>

      <footer className="footer">
        <p>Running on EKS with ALB Ingress Controller</p>
      </footer>
    </div>
  );
}

export default App;
