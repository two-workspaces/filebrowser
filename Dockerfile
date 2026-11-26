# Upstream's FileBrowser Quantum image (with ffmpeg for video previews), pinned. The
# wrapper adds the Railway entrypoint and the tools it needs: su-exec (drop to the
# image's uid 1000 after fixing the volume's owner), busybox-extras (httpd for the notice
# page when the server can't start) and coreutils (dd iflag=nocache for the page-cache
# trimmer).
FROM gtstef/filebrowser:2.1.0-stable

USER root
RUN apk add --no-cache su-exec busybox-extras coreutils

COPY --chmod=0755 railway-entrypoint.sh drop-file-cache.sh /usr/local/bin/

# The entrypoint runs as root only to chown the Railway volume (mounted root-owned),
# then runs filebrowser as uid 1000 like upstream.
WORKDIR /home/filebrowser
ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
