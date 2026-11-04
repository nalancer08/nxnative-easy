/* Original offline WebGL scene. No network, native bridge, storage or game state. */
(() => {
  'use strict';
  const canvas=document.getElementById('world'), fallback=document.getElementById('fallback');
  const halo=lottie.loadAnimation({container:document.getElementById('halo'),renderer:'svg',loop:true,autoplay:false,animationData:window.sceneData});
  const picture=window.sceneData.assets.find(a=>a.id==='original-world').p;
  fallback.src=picture;
  let active=false,reduced=false,ready=false,destroyed=false,raf=0,last=0,time=0,clicked=-20;
  let pointer=[0,0],target=[0,0],press=null,drag=0,turn=0;
  const gl=canvas.getContext('webgl',{alpha:true,antialias:true,premultipliedAlpha:true,preserveDrawingBuffer:false,powerPreference:'low-power'});
  function configure(playing,reduce,label) {
    active=!!playing;reduced=!!reduce;
    if(label)canvas.setAttribute('aria-label',label);
    canvas.setAttribute('role',reduced?'img':'button');canvas.tabIndex=reduced?-1:0;
    cancelAnimationFrame(raf);raf=0;last=0;
    if(active&&!reduced&&!document.hidden){halo.play();if(ready)raf=requestAnimationFrame(frame)}
    else{halo.goToAndStop(60,true);if(ready)draw(reduced?0:time,0)}
  }
  window.setSceneState=configure;
  window.destroyScene=()=>{destroyed=true;ready=false;active=false;cancelAnimationFrame(raf);halo.destroy();if(gl){if(texture)gl.deleteTexture(texture);programs.forEach(p=>gl.deleteProgram(p));buffers.forEach(b=>gl.deleteBuffer(b))}};
  document.addEventListener('visibilitychange',()=>configure(active,reduced));
  halo.addEventListener('DOMLoaded',()=>configure(active,reduced));
  if(!gl){fallback.style.display='block';canvas.style.display='none';return}
  const programs=[],buffers=[];
  function program(vertex,fragment) {
    function shader(kind,source){const s=gl.createShader(kind);gl.shaderSource(s,source);gl.compileShader(s);if(!gl.getShaderParameter(s,gl.COMPILE_STATUS)){const message=gl.getShaderInfoLog(s);gl.deleteShader(s);throw Error(message)}return s}
    const v=shader(gl.VERTEX_SHADER,vertex),f=shader(gl.FRAGMENT_SHADER,fragment),p=gl.createProgram();
    gl.attachShader(p,v);gl.attachShader(p,f);gl.linkProgram(p);gl.deleteShader(v);gl.deleteShader(f);
    if(!gl.getProgramParameter(p,gl.LINK_STATUS)){gl.deleteProgram(p);throw Error('Scene link failed')}
    programs.push(p);return p;
  }
  const common=`precision highp float;
    uniform float uTime,uBurst,uAspect,uTurn,uDpr,uHalo;
    uniform vec2 uPointer;
    uniform sampler2D uArt;
    varying vec2 vUV;
    mat3 rotateY(float a){return mat3(cos(a),0.,-sin(a),0.,1.,0.,sin(a),0.,cos(a));}
    mat3 rotateX(float a){return mat3(1.,0.,0.,0.,cos(a),sin(a),0.,-sin(a),cos(a));}
    vec3 camera(vec3 p){p=rotateY(uPointer.x*.18+uTurn)*rotateX(-uPointer.y*.11)*p;return p;}
    vec4 project(vec3 p){float depth=3.8/(3.8-p.z);return vec4(p.x*depth/uAspect,p.y*depth,0.,1.);}`;
  let world,points,texture;
  try {
    world=program(common+`attribute vec2 aPosition;void main(){vUV=aPosition*.5+.5;vec3 p=vec3(aPosition*vec2(1.05,.70),0.);p.z=sin(aPosition.x*2.+uTime*.55)*.025;gl_Position=project(camera(p));}`,
    common+`void main(){
      vec2 uv=vUV;
      float water=smoothstep(.50,.85,1.-uv.y)*smoothstep(.50,.78,uv.x);
      uv.x+=sin(uv.y*62.+uTime*1.4)*.006*water;
      uv.y+=sin(uv.x*39.+uTime*.8)*.004*water;
      vec2 delta=uv-(uPointer*.5+.5);float distance=length(delta);
      uv+=normalize(delta+.0001)*sin(distance*35.-uTime*2.)*.0015*exp(-distance*4.);
      vec3 color=texture2D(uArt,vec2(uv.x,1.-uv.y)).rgb;
      vec2 q=abs(vUV-.5)-vec2(.45,.42);
      float edge=length(max(q,0.))+min(max(q.x,q.y),0.)-.055;
      float alpha=1.-smoothstep(-.004,.004,edge);
      float shine=pow(max(0.,1.-abs(fract(vUV.x*.8+vUV.y*.28-uTime*.045)-.5)*9.),6.);
      color+=vec3(1.,.63,.28)*shine*.045;
      alpha*=1.-smoothstep(.03,.4,uBurst);
      gl_FragColor=vec4(color,alpha);
    }`);
    points=program(common+`attribute vec3 aSeed;varying float vAlpha;varying float vStar;
      void main(){
        vUV=aSeed.xy;float n=aSeed.z;
        vec3 home=vec3((vUV-.5)*vec2(2.1,1.4),sin(n*73.)*.025);
        float theta=vUV.x*6.2831853+uTime*.12;
        float phi=acos(2.*vUV.y-1.);
        vec3 cloud=vec3(sin(phi)*cos(theta),cos(phi),sin(phi)*sin(theta))*.78;
        cloud+=vec3(sin(n*71.+uTime*.7),cos(n*43.+uTime*.6),sin(n*29.+uTime*.5))*.07;
        vec3 p=mix(home,cloud,smoothstep(0.,1.,uBurst));
        float d=length(p.xy-uPointer*.8);p.xy+=(p.xy-uPointer*.8)*exp(-d*8.)*.08*sin(uTime*2.+n*12.);
        p.z+=sin(n*70.+uTime*.8)*.025;
        vStar=step(.995,n);
        if(vStar>.5){p=vec3(sin(n*537.+uTime*.075)*1.3,cos(n*391.+uTime*.12)*.98,sin(n*249.+uTime*.1)*.35);}
        p=camera(p);gl_Position=project(p);
        gl_PointSize=(vStar>.5?5.0:(2.8+uHalo*10.))*uDpr*(3.8/(3.8-p.z));
        vAlpha=vStar>.5?.85:(.008+smoothstep(0.,.32,uBurst)*.85);
        vAlpha*=mix(1.,.08,uHalo);
      }`,common+`varying float vAlpha;varying float vStar;void main(){
        float d=length(gl_PointCoord-.5);if(d>.5)discard;
        vec3 color=texture2D(uArt,vec2(vUV.x,1.-vUV.y)).rgb;
        color=mix(pow(max(color,vec3(.025)),vec3(.65))*1.4,mix(vec3(.12,.9,1.25),vec3(1.7,.38,.12),vUV.x),.55);
        color=mix(color,vec3(2.,.85,.3),vStar*.85);
        float alpha=exp(-d*d*22.)*vAlpha;
        gl_FragColor=vec4(color*(1.+vStar),alpha);
      }`);
  }catch(_){fallback.style.display='block';canvas.style.display='none';return}
  function buffer(data){const b=gl.createBuffer();buffers.push(b);gl.bindBuffer(gl.ARRAY_BUFFER,b);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array(data),gl.STATIC_DRAW);return b}
  const quad=buffer([-1,-1,1,-1,-1,1,-1,1,1,-1,1,1]),seeds=[];
  for(let y=0;y<88;y++)for(let x=0;x<132;x++){const seed=((x*374761393+y*668265263)>>>0)/4294967296;seeds.push((x+.5)/132,(y+.5)/88,seed)}
  const cloud=buffer(seeds);
  texture=gl.createTexture();gl.bindTexture(gl.TEXTURE_2D,texture);
  gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S,gl.CLAMP_TO_EDGE);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_T,gl.CLAMP_TO_EDGE);
  gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.LINEAR);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,gl.LINEAR);
  const image=new Image();image.onload=()=>{if(destroyed)return;gl.bindTexture(gl.TEXTURE_2D,texture);gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,gl.RGBA,gl.UNSIGNED_BYTE,image);ready=true;configure(active,reduced)};image.onerror=()=>{fallback.style.display='block';canvas.style.display='none'};image.src=picture;
  function draw(t,burst) {
    const dpr=Math.min(window.devicePixelRatio||1,1.5),width=Math.max(1,Math.round(canvas.clientWidth*dpr)),height=Math.max(1,Math.round(canvas.clientHeight*dpr));
    if(canvas.width!==width||canvas.height!==height){canvas.width=width;canvas.height=height}
    gl.viewport(0,0,width,height);gl.clearColor(0,0,0,0);gl.clear(gl.COLOR_BUFFER_BIT);gl.enable(gl.BLEND);gl.blendFunc(gl.SRC_ALPHA,gl.ONE_MINUS_SRC_ALPHA);
    for(const [p,b,name,count,glow] of [[world,quad,'aPosition',6,0],[points,cloud,'aSeed',seeds.length/3,1],[points,cloud,'aSeed',seeds.length/3,0]]){
      gl.blendFuncSeparate(gl.SRC_ALPHA,p===world?gl.ONE_MINUS_SRC_ALPHA:gl.ONE,gl.ONE,gl.ONE_MINUS_SRC_ALPHA);
      gl.useProgram(p);gl.bindBuffer(gl.ARRAY_BUFFER,b);const location=gl.getAttribLocation(p,name);gl.enableVertexAttribArray(location);gl.vertexAttribPointer(location,p===world?2:3,gl.FLOAT,false,0,0);
      for(const [name,value] of [['uTime',t],['uBurst',burst],['uAspect',width/height],['uTurn',turn],['uDpr',dpr],['uHalo',glow]])gl.uniform1f(gl.getUniformLocation(p,name),value);
      gl.uniform2fv(gl.getUniformLocation(p,'uPointer'),pointer);gl.uniform1i(gl.getUniformLocation(p,'uArt'),0);
      gl.drawArrays(p===world?gl.TRIANGLES:gl.POINTS,0,count);
    }
  }
  function frame(now){
    if(destroyed||!active||reduced||document.hidden){raf=0;return}
    raf=requestAnimationFrame(frame);if(last&&now-last<32)return;
    const dt=last?Math.min((now-last)/1000,.1):0;last=now;time+=dt;
    pointer[0]+=(target[0]-pointer[0])*.09;pointer[1]+=(target[1]-pointer[1])*.09;
    const automatic=time%18,cycle=automatic<4?Math.pow(Math.sin(automatic/4*Math.PI),2):0;
    const since=time-clicked,manual=since<4&&since>=0?Math.pow(Math.sin(since/4*Math.PI),2):0;
    draw(time,Math.max(cycle,manual));
  }
  function position(event){const r=canvas.getBoundingClientRect();return [(event.clientX-r.left)/r.width*2-1,1-(event.clientY-r.top)/r.height*2]}
  canvas.addEventListener('pointermove',event=>{target=position(event);if(press){const dx=event.clientX-press[0];drag+=Math.abs(dx);turn=Math.max(-.9,Math.min(.9,turn+dx*.003));press=[event.clientX,event.clientY]}});
  canvas.addEventListener('pointerleave',()=>{target=[0,0];press=null});
  canvas.addEventListener('pointerdown',event=>{if(reduced)return;drag=0;clicked=time;press=[event.clientX,event.clientY];canvas.setPointerCapture(event.pointerId)});
  canvas.addEventListener('pointerup',()=>{press=null});
  canvas.addEventListener('keydown',event=>{if(event.key==='Enter'||event.key===' '){event.preventDefault();if(!reduced&&!event.repeat)clicked=time}});
  canvas.addEventListener('webglcontextlost',event=>{event.preventDefault();cancelAnimationFrame(raf);ready=false;fallback.style.display='block';canvas.style.display='none'});
  window.addEventListener('resize',()=>{if(ready&&(!active||reduced))draw(reduced?0:time,0)});
})();
