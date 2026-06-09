// htmx config
htmx.config.globalViewTransitions = true;

// clipboard
const shortLinks = document.querySelectorAll(".shortLink");
shortLinks.forEach((shortLink) => {
  shortLink.addEventListener("click", async (event) => {
    event.preventDefault();
    try {
      await navigator.clipboard.writeText(event.currentTarget.href);
      const oldValue = shortLink.textContent;
      shortLink.textContent = "Copied!";
      setTimeout(() => {
        shortLink.textContent = oldValue;
      }, 2000);
    } catch (err) {
      console.error("Failed to copy text: ", err);
    }
  });
});
