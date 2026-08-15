// API configuration - read from environment variables
// In production (K8s), this comes from the Ingress path /api
const API_BASE = import.meta.env.VITE_API_URL || '/api';

export const callBackend = async () => {
  try {
    const response = await fetch(`${API_BASE}/hello`);
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    return await response.json();
  } catch (error) {
    throw new Error(`Failed to call backend: ${error.message}`);
  }
};

export const checkHealth = async () => {
  try {
    const response = await fetch(`${API_BASE}/health`);
    return response.ok;
  } catch {
    return false;
  }
};
