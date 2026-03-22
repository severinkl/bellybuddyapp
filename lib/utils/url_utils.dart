/// Returns true if [url] starts with http:// or https://.
bool isValidImageUrl(String url) =>
    url.startsWith('https://') || url.startsWith('http://');
