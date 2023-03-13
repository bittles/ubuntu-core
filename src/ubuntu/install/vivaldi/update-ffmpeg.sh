#!/bin/sh -eu

FFMPEG_VERSION_DEB=110.0.5481.100-0ubuntu0.18.04.1 # Internal FFMpeg version = 110326 (2023-02-17)
FFMPEG_MIN_GLIBC_DEB=27

available () {
  command -v "$1" >/dev/null 2>&1
}

available ldd && LIBC_MINOR_VERSION="$(ldd --version | head -n1 | sed -n '/^ldd .* [2-9]\./s/.*\.\([0-9]\+\)$/\1/p')"
LIBC_MINOR_VERSION="${LIBC_MINOR_VERSION:-27}"
check_glibc () {
  if [ "$LIBC_MINOR_VERSION" -lt "$1" ]; then
    echo "Your glibc version is too old to search for a replacement libffmpeg that supports proprietary media" >&2
    exit 1
  fi
}

FFMPEG_USE_SNAP=0
case arm64 in
  amd64|x86_64)
    FFMPEG_URL_DEB=https://launchpadlibrarian.net/651923070/chromium-codecs-ffmpeg-extra_${FFMPEG_VERSION_DEB}_amd64.deb
    FFMPEG_XZ_OFFSET_DEB=1157
    FFMPEG_SUM_DEB=9cc19bfb592e837e9b75f87227ae71f86bc09ac4b18554351da3980cddcfb600
    FFMPEG_URL_SNAP=https://api.snapcraft.io/api/v1/snaps/download/XXzVIXswXKHqlUATPqGCj2w2l7BxosS8_30.snap # Older Chromium (105) but seems to work
    FFMPEG_XZ_OFFSET_SNAP=97
    FFMPEG_LIB_OFFSET_SNAP=71227577
    FFMPEG_LENGTH_SNAP=25041168
    FFMPEG_SUM_SNAP=964b03f3ee2a5d1ab4fe27b30ff91653d49b26e1a35ecbd9026683e4e30abcfe
    FFMPEG_VERSION_SNAP=108372 # Chromium 105
    FFMPEG_MIN_GLIBC_SNAP=27
    check_glibc "$FFMPEG_MIN_GLIBC_SNAP"
    [ "$LIBC_MINOR_VERSION" -lt "$FFMPEG_MIN_GLIBC_DEB" ] && FFMPEG_USE_SNAP=1
    ;;
  armhf|armv7hl)
    FFMPEG_URL_DEB=https://launchpadlibrarian.net/651934774/chromium-codecs-ffmpeg-extra_${FFMPEG_VERSION_DEB}_armhf.deb
    FFMPEG_XZ_OFFSET_DEB=1157
    FFMPEG_SUM_DEB=6ab15ce63a254f28171d0aa6bdb12f8853a7be772e9d8c3260de2a2ab6e7423e
    check_glibc "$FFMPEG_MIN_GLIBC_DEB"
    ;;
  arm64|aarch64)
    FFMPEG_URL_DEB=https://launchpadlibrarian.net/651935011/chromium-codecs-ffmpeg-extra_${FFMPEG_VERSION_DEB}_arm64.deb
    FFMPEG_XZ_OFFSET_DEB=1157
    FFMPEG_SUM_DEB=af1bbde11e1bb07b5fa77d5cdd23a018fdbfbf0352d5654c511358a3a2dc23b3
    check_glibc "$FFMPEG_MIN_GLIBC_DEB"
    ;;
esac

# Correct the version if one of the above URLs uses different than the default
if ! echo "$FFMPEG_URL_DEB" | grep -qF "$FFMPEG_VERSION_DEB"; then
  NEW_FFMPEG_VERSION_DEB="$(echo "$FFMPEG_URL_DEB" | grep -o '[0-9]\{3,\}\.[0-9]\+\.[0-9]\{4,\}\.[0-9]\+-[a-z0-9\.]\+')"
  if [ -n "$NEW_FFMPEG_VERSION_DEB" ]; then
    FFMPEG_VERSION_DEB="$NEW_FFMPEG_VERSION_DEB"
  fi
fi

if [ "${1-}" = "--system" ]; then
  shift 1
fi
if [ "${1-}" = "--user" ]; then
  FFMPEG_INSTALL_DIR_DEB="$HOME/.local/lib/vivaldi/media-codecs-$FFMPEG_SUM_DEB"
  case 'arm64' in
    amd64|x86_64) FFMPEG_INSTALL_DIR_SNAP="$HOME/.local/lib/vivaldi/media-codecs-$FFMPEG_SUM_SNAP" ;;
  esac
  shift 1
else
  FFMPEG_INSTALL_DIR_DEB="/var/opt/vivaldi/media-codecs-$FFMPEG_SUM_DEB"
  case 'arm64' in
    amd64|x86_64) FFMPEG_INSTALL_DIR_SNAP="/var/opt/vivaldi/media-codecs-$FFMPEG_SUM_SNAP" ;;
  esac
  if [ "${USER:-}" != "root" ]; then
    echo "You may need to be root (or rerun this command with sudo)" >&2
  fi
fi

cleanup_files () {
  # Cleanup needs to be able to handle files from earlier installs, where the
  # numbered path could be different.
  if ls "${FFMPEG_INSTALL_DIR_DEB%/media-codecs-*}"/media-codecs-*/libffmpeg.so >/dev/null 2>&1; then
    rm -f "${FFMPEG_INSTALL_DIR_DEB%/media-codecs-*}"/media-codecs-*/libffmpeg.so
  fi
  if [ -d "${FFMPEG_INSTALL_DIR_DEB%/media-codecs-*}" ]; then
    find "${FFMPEG_INSTALL_DIR_DEB%/media-codecs-*}" -depth -type d -empty -exec rmdir {} \;
  fi
}

if [ "${1-}" = "--undo" ]; then
  cleanup_files
  exit
fi

if ! available sha256sum; then
  echo "sha256sum is not installed; aborting" >&2
  exit 1
fi

# If a suitable file already exists we do not need to do anything and
# can exit early.
case 'arm64' in
  amd64|x86_64)
    if [ -e "$FFMPEG_INSTALL_DIR_DEB/libffmpeg.so" ] && echo "$FFMPEG_SUM_DEB  $FFMPEG_INSTALL_DIR_DEB/libffmpeg.so" | sha256sum -c >/dev/null 2>&1; then
      echo "Proprietary media codecs (${FFMPEG_VERSION_DEB%-*}) was already present"
      chmod -R u+rwX,go+rX-w "${FFMPEG_INSTALL_DIR_DEB%/media-codecs-*}"
      exit 0
    elif [ -e "$FFMPEG_INSTALL_DIR_SNAP/libffmpeg.so" ] && echo "$FFMPEG_SUM_SNAP  $FFMPEG_INSTALL_DIR_SNAP/libffmpeg.so" | sha256sum -c >/dev/null 2>&1; then
      echo "Proprietary media codecs ($FFMPEG_VERSION_SNAP) was already present"
      chmod -R u+rwX,go+rX-w "${FFMPEG_INSTALL_DIR_SNAP%/media-codecs-*}"
      exit 0
    fi
    ;;
  *)
    if [ -e "$FFMPEG_INSTALL_DIR_DEB/libffmpeg.so" ] && echo "$FFMPEG_SUM_DEB  $FFMPEG_INSTALL_DIR_DEB/libffmpeg.so" | sha256sum -c >/dev/null 2>&1; then
      echo "Proprietary media codecs (${FFMPEG_VERSION_DEB%-*}) was already present"
      chmod -R u+rwX,go+rX-w "${FFMPEG_INSTALL_DIR_DEB%/media-codecs-*}"
      exit 0
    fi
    ;;
esac

# We don't need to check certificates because we verify package contents with
# checksums. By avoiding the check we also allow for download on a distro that
# lacks an up to date certificate store (see: VB-68785)
if available wget; then
  DOWNLOAD="wget -O- --no-check-certificate"
  CHECK_DOWNLOAD="wget --spider"
elif available curl; then
  DOWNLOAD="curl -L --insecure"
  CHECK_DOWNLOAD="curl -I"
else
  echo "Neither Wget nor cURL is installed; aborting" >&2
  exit 1
fi

# Remove any previous version before installing the new one
cleanup_files

# Check the download URL for the .deb is (still) valid
case 'arm64' in
  amd64|x86_64)
    if [ "$FFMPEG_USE_SNAP" = '0' ] && ! $CHECK_DOWNLOAD "$FFMPEG_URL_DEB" 2>&1 | grep -q 'HTTP.*200'; then
      FFMPEG_USE_SNAP='1'
    fi
    ;;
  *)
    if ! $CHECK_DOWNLOAD "$FFMPEG_URL_DEB" 2>&1 | grep -q 'HTTP.*200'; then
      echo "Cannot locate a suitable library to provide support for proprietary media." >&2
      exit 1
    fi
    ;;
esac

# Fetch and extract libffmpeg
if [ "$FFMPEG_USE_SNAP" = '1' ]; then
  mkdir -p "$FFMPEG_INSTALL_DIR_SNAP"
  # We hide the download progress here because wget/curl will complain since
  # they are prevented from completing their download. This may confuse
  # the user, causing them to suspect something has gone wrong.
  $DOWNLOAD "$FFMPEG_URL_SNAP" 2>/dev/null | tail -c+"$FFMPEG_XZ_OFFSET_SNAP" | xz -d | tail -c+"$FFMPEG_LIB_OFFSET_SNAP" | head -c"$FFMPEG_LENGTH_SNAP" > "$FFMPEG_INSTALL_DIR_SNAP/libffmpeg.so" ||:
  chmod -R u+rwX,go+rX-w "${FFMPEG_INSTALL_DIR_SNAP%/media-codecs-*}"
  if ! echo "$FFMPEG_SUM_SNAP  $FFMPEG_INSTALL_DIR_SNAP/libffmpeg.so" | sha256sum -c >/dev/null 2>&1; then
    echo "The extracted libffmpeg.so does not match the expected sha256sum; aborting" >&2
    cleanup_files
    exit 1
  fi
  echo "Proprietary media codecs ($FFMPEG_VERSION_SNAP) has been installed (PLEASE RESTART VIVALDI)"
else
  mkdir -p "$FFMPEG_INSTALL_DIR_DEB"
  $DOWNLOAD "$FFMPEG_URL_DEB" | tail -c+"$FFMPEG_XZ_OFFSET_DEB" | xz -d | tar fOx - ./usr/lib/chromium-browser/libffmpeg.so > "$FFMPEG_INSTALL_DIR_DEB/libffmpeg.so" ||:
  chmod -R u+rwX,go+rX-w "${FFMPEG_INSTALL_DIR_DEB%/media-codecs-*}"
  if ! echo "$FFMPEG_SUM_DEB  $FFMPEG_INSTALL_DIR_DEB/libffmpeg.so" | sha256sum -c >/dev/null 2>&1; then
    echo "The extracted libffmpeg.so does not match the expected sha256sum; aborting" >&2
    cleanup_files
    exit 1
  fi
  echo "Proprietary media codecs (${FFMPEG_VERSION_DEB%-*}) has been installed (PLEASE RESTART VIVALDI)"
fi
