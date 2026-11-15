(function(){
  var html = document.documentElement;
  // idioma: el guardado, o el del navegador
  var guardado = null;
  try { guardado = localStorage.getItem("gaia_idioma"); } catch(e) {}
  var inicial = guardado || ((navigator.language || "es").toLowerCase().indexOf("en") === 0 ? "en" : "es");
  function poner(l){
    html.lang = l;
    var titulo = document.querySelector("title[data-" + l + "]");
    if (titulo) { document.title = titulo.getAttribute("data-" + l); }
    try { localStorage.setItem("gaia_idioma", l); } catch(e) {}
  }
  poner(inicial);
  document.querySelectorAll(".idioma button").forEach(function(b){
    b.addEventListener("click", function(){ poner(b.getAttribute("data-l")); });
  });
  // navegación con fondo al bajar
  var nav = document.getElementById("nav");
  function alBajar(){ nav.classList.toggle("fondo", window.scrollY > 40); }
  alBajar(); window.addEventListener("scroll", alBajar, {passive:true});
  // revelar al entrar en pantalla
  var io = new IntersectionObserver(function(es){
    es.forEach(function(e){ if(e.isIntersecting){ e.target.classList.add("ya"); io.unobserve(e.target); } });
  }, {threshold:.15});
  document.querySelectorAll(".rev,[data-acto]").forEach(function(el){ io.observe(el); });
})();
