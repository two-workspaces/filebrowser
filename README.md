# Deploy and Host FileBrowser on Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/filebrowser?referralCode=sLjDXb&utm_medium=integration&utm_source=button&utm_campaign=filebrowser)

FileBrowser Quantum is a self-hosted web file manager: upload, download, move and rename files and folders from any browser, search them instantly, preview images, videos, PDFs and documents, edit text files in place, and share files or folders through links with an optional password and expiry. It adds multiple users with per-folder permissions, WebDAV for desktop and phone clients, API tokens, and optional single sign-on. It is the actively maintained successor to the original File Browser project. This template runs FileBrowser Quantum 2.1.0 on Railway with a persistent volume and an admin account set up from your variables.

## About Hosting FileBrowser

Deploy, wait for the green check, and open the Railway domain. Sign in as `admin` with the generated `FILEBROWSER_ADMIN_PASSWORD`, which is on the service's Variables tab.

**The password variable wins.** FileBrowser applies `FILEBROWSER_ADMIN_PASSWORD` to the admin account on every start. To change the admin password, change the variable and redeploy; a password changed only in the app's settings is replaced at the next restart. That also makes the variable your password reset.

**Your files live on the volume at `/data`:** uploads go to `/data/files`, and the user, share and settings database is `/data/database.sqlite`. Redeploys, restarts and upgrades keep them. Grow the volume in the service's settings when it fills up, and back it up with Railway's volume backups.

**More users:** add them in Settings > User Management, and choose which folders each one can see and change. Sign-up from the login page is off.

**WebDAV:** create an API token in Settings > API Tokens, then connect your client to `https://your-app.up.railway.app/dav/files/` with any username and the token as the password.

**Custom domain:** add it in Settings > Networking, then set `FILEBROWSER_EXTERNAL_URL=https://files.example.com` so share links use it, and redeploy.

**Your own config:** to use FileBrowser's full configuration (single sign-on, LDAP, OnlyOffice, more sources), put a `config.yaml` at `/data/config.yaml`. It then replaces this template's generated settings entirely; start from FileBrowser's documentation.

## Common Use Cases

- A private Dropbox or Google Drive replacement with share links
- Sending large files to clients or friends through a password-protected link
- A WebDAV drive for desktop, phone and backup apps
- A shared folder for a family or small team, with per-user permissions
- Browsing and previewing photos, videos and documents from any device

## Dependencies for FileBrowser Hosting

- None. One service with one volume; the database is SQLite on the volume.

### Deployment Dependencies

- [FileBrowser Quantum on GitHub](https://github.com/gtsteffaniak/filebrowser)
- [FileBrowser Quantum documentation](https://filebrowserquantum.com)
- [Template source](https://github.com/two-workspaces/filebrowser)

### Implementation Details

- **Admin:** `FILEBROWSER_ADMIN_USERNAME` and `FILEBROWSER_ADMIN_PASSWORD` set the admin account. If the password is empty, FileBrowser prints a one-time password in the deploy logs on the first boot and asks you to change it at the first login.
- **Login protection:** FileBrowser rate-limits logins and locks out an address after repeated failures. The template trusts Railway's edge for the visitor's address, so a stranger's guesses lock out only the stranger. New passwords need 8 characters or more.
- **Share links** use the Railway domain, or `FILEBROWSER_EXTERNAL_URL` when set.
- **Never crash-looping:** if FileBrowser stops within a minute of starting, for example on a broken `/data/config.yaml`, the service shows a "FileBrowser is not running" page and the deploy logs say what to fix.
- **Memory:** Linux keeps uploaded and viewed files in its page cache, which Railway counts as the service's memory, so the template drops that cache every 15 minutes. Thumbnails are generated two at a time, which keeps preview bursts small.
- **Volume ownership:** Railway mounts volumes as root, so the entrypoint hands `/data` to the image's user (uid 1000) and then runs FileBrowser as that user, like upstream.
- **Healthcheck:** `/api/health`.
- **Image:** upstream's `gtstef/filebrowser:2.1.0-stable` (with ffmpeg for video previews), pinned, plus a small entrypoint.

## Why Deploy FileBrowser on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying FileBrowser on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
