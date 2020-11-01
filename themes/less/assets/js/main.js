document.addEventListener("DOMContentLoaded", function () {
  new LazyLoad({
    elements_selector: ".lazyload",
    skip_invisible: false
  });
  mediumZoom(document.querySelectorAll('[data-action="zoom"]'), {margin: 20});
})
