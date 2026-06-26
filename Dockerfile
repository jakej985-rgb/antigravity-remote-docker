# =============================================================================
# Antigravity Remote Docker
# A GPU-accelerated container for running Google Antigravity remotely via noVNC
# =============================================================================

FROM nvidia/cuda:12.3.1-runtime-ubuntu22.04

LABEL maintainer="raphl"
LABEL description="Google Antigravity with noVNC remote access and GPU support"

# =============================================================================
# Environment Configuration
# =============================================================================
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    DISPLAY=:1 \
    DISPLAY_WIDTH=1920 \
    DISPLAY_HEIGHT=1080 \
    DISPLAY_DEPTH=24 \
    VNC_PORT=5901 \
    NOVNC_PORT=6080 \
    VNC_PASSWORD=antigravity \
    USER=antigravity \
    UID=1000 \
    GID=1000 \
    HOME=/home/antigravity \
    ANTIGRAVITY_HOME=/opt/antigravity-ide \
    WORKSPACE=/home/antigravity/workspace

# =============================================================================
# System Dependencies
# =============================================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Core utilities
    ca-certificates \
    curl \
    wget \
    gnupg \
    sudo \
    locales \
    tzdata \
    dbus-x11 \
    # X11 and desktop
    xvfb \
    x11vnc \
    tigervnc-standalone-server \
    tigervnc-common \
    tigervnc-tools \
    xfce4 \
    xfce4-goodies \
    xfce4-terminal \
    # Fonts and theming
    fonts-dejavu \
    fonts-liberation \
    fonts-noto \
    gtk2-engines-pixbuf \
    adwaita-icon-theme \
    # noVNC dependencies
    python3 \
    python3-pip \
    python3-numpy \
    # Audio (optional, for future use)
    pulseaudio \
    # Clipboard support
    xclip \
    xsel \
    # Process management
    supervisor \
    # Auto-updates (tarball-based, curl is already present above)
    # Utilities
    nano \
    vim \
    git \
    htop \
    procps \
    net-tools \
    # Window management (for auto-maximize)
    wmctrl \
    xdotool \
    # X11 display utilities (required by scripts)
    x11-xserver-utils \
    x11-utils \
    xcvt \
    # Networking utilities (nc used by start-novnc.sh)
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# Install Google Chrome
# =============================================================================
RUN curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y google-chrome-stable \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# Locale Configuration
# =============================================================================
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# =============================================================================
# Install noVNC and websockify
# =============================================================================
RUN mkdir -p /opt/novnc \
    && curl -fsSL https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz | tar -xz -C /opt/novnc --strip-components=1 \
    && mkdir -p /opt/websockify \
    && curl -fsSL https://github.com/novnc/websockify/archive/refs/tags/v0.11.0.tar.gz | tar -xz -C /opt/websockify --strip-components=1 \
    && ln -sf /opt/websockify /opt/novnc/utils/websockify

# Create custom index.html that forces English language and auto-connects
RUN echo '<!DOCTYPE html><html><head><meta http-equiv="refresh" content="0;url=vnc.html?autoconnect=true&resize=remote&lang=en"></head><body>Redirecting...</body></html>' > /opt/novnc/index.html

# =============================================================================
# Install Antigravity IDE (Tarball)
# =============================================================================

RUN mkdir -p ${ANTIGRAVITY_HOME} \
    && curl -fsSL \
    "https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.1.1-6123990880747520/linux-x64/Antigravity%20IDE.tar.gz" \
    -o /tmp/antigravity.tar.gz \
    && tar -xzf /tmp/antigravity.tar.gz \
        -C ${ANTIGRAVITY_HOME} \
        --strip-components=1 \
    && ln -sf ${ANTIGRAVITY_HOME}/antigravity-ide /usr/local/bin/antigravity-ide \
    && chmod +x ${ANTIGRAVITY_HOME}/antigravity-ide \
    && rm -f /tmp/antigravity.tar.gz

ENV PATH="${ANTIGRAVITY_HOME}:${PATH}"

# =============================================================================
# Create Non-Root User
# =============================================================================
RUN groupadd -g ${GID} ${USER} \
    && useradd -m -u ${UID} -g ${GID} -s /bin/bash ${USER} \
    && echo "${USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/${USER} \
    && chmod 0440 /etc/sudoers.d/${USER}
RUN chown -R ${USER}:${USER} ${ANTIGRAVITY_HOME}

# =============================================================================
# Configure VNC and Desktop
# =============================================================================
RUN mkdir -p /home/${USER}/.vnc /home/${USER}/.config \
    && chown -R ${USER}:${USER} /home/${USER}

# =============================================================================
# Copy Configuration Files
# =============================================================================
COPY --chown=${USER}:${USER} config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY --chown=${USER}:${USER} scripts/ /opt/scripts/
RUN chmod +x /opt/scripts/*.sh

# =============================================================================
# Exposed Ports
# =============================================================================
# VNC: 5901, noVNC: 6080
EXPOSE ${VNC_PORT} ${NOVNC_PORT}

# =============================================================================
# Copy Configuration Defaults
# =============================================================================
RUN mkdir -p /opt/defaults
COPY config/xfce4-panel.xml /opt/defaults/xfce4-panel.xml

# =============================================================================
# Volumes
# =============================================================================
VOLUME ["/home/${USER}/workspace", "/home/${USER}/.config"]

# =============================================================================
# Health Check
# =============================================================================
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:${NOVNC_PORT}/ || exit 1

# =============================================================================
# Entrypoint
# =============================================================================
USER ${USER}
WORKDIR /home/${USER}

ENTRYPOINT ["/opt/scripts/entrypoint.sh"]
CMD ["supervisord"]
