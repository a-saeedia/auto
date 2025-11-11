### Crypto News Farsi Publisher

Automated Telegram bot that fetches crypto news from RSS/Atom feeds, humanizes with Google Gemini, translates to Persian, and posts to a Telegram channel.

#### One-line install (user systemd service)
Replace <your-username> and fill secrets:

```bash
curl -fsSL https://raw.githubusercontent.com/<your-username>/crypto-news-farsi-bot/main/install.sh | bash -s -- \
  --repo https://github.com/<your-username>/crypto-news-farsi-bot.git \
  --bot-token '123:abc' \
  --admin-id 123456789 \
  --channel-id '-1001234567890' \
  --gemini-key 'YOUR_GEMINI_API_KEY' \
  --feeds 'https://feed1.com/rss,https://feed2.com/rss'
