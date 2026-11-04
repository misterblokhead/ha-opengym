# Both images are pinned by tag and multi-arch index digest; Dependabot updates the two together.
FROM ghcr.io/duartesantos8/opengym-web:1.4.3@sha256:e77ef879d10549acc88a888e0cd4d566592c5680bee6436b05071678fcf8b512 AS web
# The web image's CSP carries the hash of openGym's inline script, which changes per version.
# Only frame-ancestors changes, so Home Assistant's ingress can frame the app.
RUN printf '%s' "$CONTENT_SECURITY_POLICY" | sed "s/frame-ancestors 'none'/frame-ancestors 'self'/" > /tmp/csp \
 && grep -q "frame-ancestors 'self'" /tmp/csp

FROM ghcr.io/duartesantos8/opengym-api:1.4.3@sha256:21d1fde39470d9c91424db51be64f5dd57c75b0b493345016f1d6e268dceae16
RUN apk add --no-cache nginx gettext
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
