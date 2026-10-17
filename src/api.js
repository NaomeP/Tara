export const API = import.meta.env.VITE_API_URL || 'http://localhost:4000/api';
export const resolveImageUrl = image => image?.startsWith('/api/') ? `${new URL(API, window.location.origin).origin}${image}` : image;

export async function api(path, options = {}) {
  const response = await fetch(`${API}${path}`, {
    ...options,
    headers: { 'Content-Type': 'application/json', ...(options.token ? { Authorization: `Bearer ${options.token}` } : {}), ...options.headers },
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(data.error || 'Something went wrong. Please try again.');
  const normalizeImages = value => {
    if (Array.isArray(value)) return value.map(normalizeImages);
    if (!value || typeof value !== 'object') return value;
    return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, (key === 'image' || key === 'image_url') && typeof item === 'string' ? resolveImageUrl(item) : normalizeImages(item)]));
  };
  return normalizeImages(data);
}
