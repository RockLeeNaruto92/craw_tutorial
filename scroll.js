var doScroll = function(count, max_time){
  if (count >= max_time) {
    console.log("Stop scroll");
    return
  };

  window.setTimeout(function(){
    window.scrollTo(0,document.body.scrollHeight);
    count += 1;
    console.log("DoScroll: " + count);
    doScroll(count, max_time);
  }, 1000);
}

doScroll(0, 100);
