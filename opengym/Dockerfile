# Both images are pinned by tag and multi-arch index digest; Dependabot updates the two together.
FROM ghcr.io/duartesantos8/opengym-web:1.4.4@sha256:33575782762f6cc9181f5e33616d55bf718bcd56338b714f22cb5d01e1adc278 AS web
# The web image's CSP carries the hash of openGym's inline script, which changes per version.
# Only frame-ancestors changes, so Home Assistant's ingress can frame the app.
RUN printf '%s' "$CONTENT_SECURITY_POLICY" | sed "s/frame-ancestors 'none'/frame-ancestors 'self'/" > /tmp/csp \
 && grep -q "frame-ancestors 'self'" /tmp/csp

FROM ghcr.io/duartesantos8/opengym-api:1.4.3@sha256:21d1fde39470d9c91424db51be64f5dd57c75b0b493345016f1d6e268dceae16
# su-exec starts openGym and nginx as unprivileged users. nginx's "user" line only applies to a root master.
RUN apk add --no-cache nginx gettext su-exec \
 && sed -i '/^user nginx;$/d' /etc/nginx/nginx.conf \
 && ! grep -q '^user ' /etc/nginx/nginx.conf
COPY --from=web /usr/share/nginx/html /usr/share/nginx/html
COPY --from=web /etc/nginx/templates/default.conf.template /etc/opengym/nginx.conf.template
COPY --from=web /tmp/csp /etc/opengym/csp
# The build fails if the replacement did not apply (openGym changed its template).
RUN sed -i 's/X-Frame-Options "DENY"/X-Frame-Options "SAMEORIGIN"/g' /etc/opengym/nginx.conf.template \
 && grep -q 'X-Frame-Options "SAMEORIGIN"' /etc/opengym/nginx.conf.template \
 && ! grep -q 'X-Frame-Options "DENY"' /etc/opengym/nginx.conf.template
COPY realip.conf /etc/nginx/http.d/00-realip.conf
COPY address.mjs run.sh /opt/opengym/
RUN chmod +x /opt/opengym/run.sh
# The api image checks health every 5 min; the Supervisor shows "starting" until the first check passes.
HEALTHCHECK --interval=10s --timeout=5s --retries=3 CMD wget -q --spider http://127.0.0.1:8099/api/health || exit 1
CMD ["/opt/opengym/run.sh"]
