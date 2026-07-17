(() => {
  "use strict";

  const catalogURL = "/skins/catalog.json";
  const directory = document.querySelector("#skin-directory");
  const template = document.querySelector("#skin-card-template");
  const searchInput = document.querySelector("#skin-search");
  const sortInput = document.querySelector("#skin-sort");
  const modeButtons = Array.from(document.querySelectorAll("[data-mode]"));
  const resultStatus = document.querySelector("#skin-results-status");
  const emptyState = document.querySelector("#skin-empty");
  const clearFiltersButton = document.querySelector("[data-clear-filters]");
  const dialog = document.querySelector("#skin-detail");
  const toast = document.querySelector("#skin-toast");

  if (!directory || !template || !dialog) return;

  const state = {
    skins: [],
    query: "",
    mode: "all",
    sort: "featured",
    activeSkin: null,
    toastTimer: null
  };

  function normalized(value) {
    return String(value || "").trim().toLocaleLowerCase();
  }

  function formatBytes(bytes) {
    const value = Number(bytes || 0);
    if (!Number.isFinite(value) || value <= 0) return "—";
    if (value < 1024) return `${value} B`;
    if (value < 1024 * 1024) return `${Math.round(value / 1024)} KB`;
    return `${(value / (1024 * 1024)).toFixed(1)} MB`;
  }

  function skinSearchText(skin) {
    return normalized([
      skin.name,
      skin.author?.name,
      skin.summary,
      skin.description,
      ...(skin.tags || []),
      ...(skin.modes || [])
    ].join(" "));
  }

  function visibleSkins() {
    const query = normalized(state.query);
    const filtered = state.skins.filter((skin) => {
      const matchesQuery = !query || skinSearchText(skin).includes(query);
      const matchesMode = state.mode === "all" || (skin.modes || []).includes(state.mode);
      return matchesQuery && matchesMode;
    });

    return filtered.sort((left, right) => {
      if (state.sort === "name") return left.name.localeCompare(right.name);
      if (state.sort === "newest") {
        return String(right.publishedAt || "").localeCompare(String(left.publishedAt || ""))
          || right.name.localeCompare(left.name);
      }
      return Number(Boolean(right.featured)) - Number(Boolean(left.featured))
        || Number(left.featuredOrder || 999) - Number(right.featuredOrder || 999)
        || String(right.publishedAt || "").localeCompare(String(left.publishedAt || ""))
        || left.name.localeCompare(right.name);
    });
  }

  function appendPalette(container, palette) {
    container.replaceChildren();
    for (const color of palette || []) {
      const swatch = document.createElement("span");
      swatch.style.setProperty("--swatch", color);
      swatch.title = color;
      swatch.setAttribute("aria-label", color);
      container.append(swatch);
    }
  }

  function appendTags(container, tags) {
    container.replaceChildren();
    for (const tag of tags || []) {
      const item = document.createElement("span");
      item.textContent = tag;
      container.append(item);
    }
  }

  function cardForSkin(skin, index) {
    const card = template.content.firstElementChild.cloneNode(true);
    card.dataset.slug = skin.slug;

    const image = card.querySelector("img");
    image.src = skin.previewPath;
    image.alt = `${skin.name} skin shown on a ThumbConsole keypad`;

    card.querySelector(".skin-card-number").textContent = String(index + 1).padStart(2, "0");
    const featured = card.querySelector(".skin-card-featured");
    featured.hidden = !skin.featured;
    card.querySelector(".skin-card-author").textContent = `by ${skin.author?.name || "Unknown creator"}`;
    card.querySelector("h3").textContent = skin.name;
    card.querySelector(".skin-card-summary").textContent = skin.summary || skin.description;
    appendPalette(card.querySelector(".skin-card-palette"), skin.palette);
    appendTags(card.querySelector(".skin-card-tags"), [...new Set([...(skin.modes || []), ...(skin.tags || []).slice(0, 2)])]);

    for (const button of card.querySelectorAll("[data-open-detail]")) {
      button.addEventListener("click", () => openDetail(skin));
    }
    card.querySelector("[data-install]").addEventListener("click", (event) => installSkin(skin, event.currentTarget));
    return card;
  }

  function renderDirectory() {
    const skins = visibleSkins();
    directory.replaceChildren(...skins.map(cardForSkin));
    directory.setAttribute("aria-busy", "false");
    emptyState.hidden = skins.length !== 0;
    const noun = skins.length === 1 ? "skin" : "skins";
    resultStatus.textContent = `${skins.length} ${noun}${state.query || state.mode !== "all" ? " found" : " in the directory"}`;
  }

  function setDetailText(selector, value) {
    const node = dialog.querySelector(selector);
    if (node) node.textContent = value || "—";
  }

  function openDetail(skin, updateURL = true) {
    state.activeSkin = skin;
    const image = dialog.querySelector("[data-detail-preview]");
    image.src = skin.previewPath;
    image.alt = `${skin.name} skin shown on a ThumbConsole keypad`;
    setDetailText("[data-detail-kicker]", `${(skin.modes || []).join(" + ")} / .pocketpad`);
    setDetailText("[data-detail-name]", skin.name);
    setDetailText("[data-detail-description]", skin.description || skin.summary);
    setDetailText("[data-detail-version]", skin.version);
    setDetailText("[data-detail-license]", skin.license);
    setDetailText("[data-detail-size]", formatBytes(skin.packageByteCount));
    setDetailText("[data-detail-sha]", skin.packageSHA256);

    const author = dialog.querySelector("[data-detail-author]");
    author.textContent = skin.author?.name || "Unknown creator";
    const authorURL = skin.author?.url || skin.homepage || "#";
    author.href = authorURL;
    if (authorURL !== "#") {
      author.target = "_blank";
      author.rel = "noreferrer";
    } else {
      author.removeAttribute("href");
      author.removeAttribute("target");
      author.removeAttribute("rel");
    }

    appendPalette(dialog.querySelector("[data-detail-palette]"), skin.palette);
    appendTags(dialog.querySelector("[data-detail-tags]"), [...new Set([...(skin.modes || []), ...(skin.tags || [])])]);
    dialog.querySelector("[data-detail-featured]").hidden = !skin.featured;
    const download = dialog.querySelector("[data-detail-download]");
    download.href = skin.downloadPath;
    download.download = skin.downloadPath.split("/").pop();
    dialog.querySelector("[data-detail-install]").onclick = (event) => installSkin(skin, event.currentTarget);

    if (!dialog.open) dialog.showModal();
    if (updateURL) {
      const url = new URL(window.location.href);
      url.searchParams.set("skin", skin.slug);
      history.pushState({ skin: skin.slug }, "", url);
    }
  }

  function closeDetail(updateURL = true) {
    if (dialog.open) dialog.close();
    state.activeSkin = null;
    if (updateURL) {
      const url = new URL(window.location.href);
      url.searchParams.delete("skin");
      history.pushState({}, "", url);
    }
  }

  function showToast(message, tone = "success") {
    window.clearTimeout(state.toastTimer);
    toast.textContent = message;
    toast.dataset.tone = tone;
    toast.hidden = false;
    state.toastTimer = window.setTimeout(() => {
      toast.hidden = true;
    }, 5200);
  }

  async function sha256Hex(blob) {
    if (!window.crypto?.subtle) return null;
    const digest = await window.crypto.subtle.digest("SHA-256", await blob.arrayBuffer());
    return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
  }

  function downloadBlob(blob, filename) {
    const objectURL = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = objectURL;
    link.download = filename;
    link.hidden = true;
    document.body.append(link);
    link.click();
    link.remove();
    window.setTimeout(() => URL.revokeObjectURL(objectURL), 1500);
  }

  async function installSkin(skin, button) {
    const originalLabel = button.textContent;
    try {
      button.disabled = true;
      button.textContent = "checking…";
      showToast(`Checking ${skin.name} before opening it…`);

      const response = await fetch(skin.downloadPath, { headers: { Accept: "application/vnd.pocketpad.skin+zip" } });
      if (!response.ok) throw new Error(`Download failed (${response.status})`);
      const blob = await response.blob();
      if (blob.size !== skin.packageByteCount) throw new Error("Package size did not match the directory record.");
      const digest = await sha256Hex(blob);
      if (digest && digest !== skin.packageSHA256) throw new Error("Package hash did not match the directory record.");

      const filename = skin.downloadPath.split("/").pop() || `${skin.slug}.pocketpad`;
      const file = new File([blob], filename, { type: "application/vnd.pocketpad.skin+zip" });
      let canShareFile = false;
      try {
        canShareFile = Boolean(navigator.share && navigator.canShare?.({ files: [file] }));
      } catch (_) {
        canShareFile = false;
      }

      if (canShareFile) {
        button.textContent = "opening…";
        try {
          await navigator.share({
            title: `${skin.name} for ThumbConsole`,
            text: `Install the ${skin.name} appearance-only skin in ThumbConsole.`,
            files: [file]
          });
          showToast(`${skin.name} is ready—choose ThumbConsole to review and install it.`);
          return;
        } catch (error) {
          if (error?.name === "AbortError") {
            showToast("Install canceled. Nothing changed.", "neutral");
            return;
          }
          // Browsers occasionally advertise file sharing but reject custom package types.
        }
      }

      downloadBlob(blob, filename);
      showToast(`${skin.name} downloaded. Open the .pocketpad file in ThumbConsole to review it.`);
    } catch (error) {
      showToast(error.message || "The skin could not be downloaded safely.", "error");
    } finally {
      button.disabled = false;
      button.textContent = originalLabel;
    }
  }

  function selectMode(mode) {
    state.mode = mode;
    for (const button of modeButtons) {
      button.setAttribute("aria-pressed", String(button.dataset.mode === mode));
    }
    renderDirectory();
  }

  async function loadCatalog() {
    try {
      const response = await fetch(catalogURL, { headers: { Accept: "application/json" }, cache: "no-cache" });
      if (!response.ok) throw new Error(`Directory unavailable (${response.status})`);
      const catalog = await response.json();
      if (catalog.schemaVersion !== 1 || !Array.isArray(catalog.skins)) {
        throw new Error("The directory returned an unsupported catalog.");
      }
      state.skins = catalog.skins;
      for (const node of document.querySelectorAll("[data-skin-count]")) {
        node.textContent = String(state.skins.length);
      }
      renderDirectory();

      const slug = new URL(window.location.href).searchParams.get("skin");
      const selected = state.skins.find((skin) => skin.slug === slug);
      if (selected) openDetail(selected, false);
    } catch (error) {
      directory.setAttribute("aria-busy", "false");
      resultStatus.textContent = "Directory unavailable";
      const message = document.createElement("div");
      message.className = "skin-load-error";
      const heading = document.createElement("h3");
      heading.textContent = "the directory could not load.";
      const copy = document.createElement("p");
      copy.textContent = `${error.message || "Try again shortly."} You can still use the direct downloads below.`;
      message.append(heading, copy);
      directory.replaceChildren(message);
    }
  }

  searchInput?.addEventListener("input", (event) => {
    state.query = event.currentTarget.value;
    renderDirectory();
  });
  sortInput?.addEventListener("change", (event) => {
    state.sort = event.currentTarget.value;
    renderDirectory();
  });
  for (const button of modeButtons) {
    button.addEventListener("click", () => selectMode(button.dataset.mode));
  }
  clearFiltersButton?.addEventListener("click", () => {
    state.query = "";
    state.mode = "all";
    if (searchInput) searchInput.value = "";
    selectMode("all");
    searchInput?.focus();
  });

  dialog.addEventListener("close", () => {
    if (!state.activeSkin) return;
    const url = new URL(window.location.href);
    if (url.searchParams.has("skin")) {
      url.searchParams.delete("skin");
      history.replaceState({}, "", url);
    }
    state.activeSkin = null;
  });
  dialog.addEventListener("click", (event) => {
    if (event.target === dialog) closeDetail();
  });
  window.addEventListener("popstate", () => {
    const slug = new URL(window.location.href).searchParams.get("skin");
    const selected = state.skins.find((skin) => skin.slug === slug);
    if (selected) openDetail(selected, false);
    else if (dialog.open) {
      state.activeSkin = null;
      dialog.close();
    }
  });

  loadCatalog();
})();
