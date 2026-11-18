"""Original deterministic score and synthesis; no downloaded samples or melodies."""
import numpy as np, wave, pathlib, json, subprocess
OUT=pathlib.Path(__file__).resolve().parents[2]/'assets/audio'
SR=44100
rng=np.random.default_rng(20261117)
def save(name,x):
    x=np.asarray(x); x-=x.mean(axis=0)
    with wave.open(str(OUT/name),'wb') as w:
        w.setnchannels(1 if x.ndim==1 else x.shape[1]);w.setsampwidth(2);w.setframerate(SR)
        w.writeframes((np.clip(x,-1,1)*32767).astype('<i2').tobytes())
    return {'peak_dbfs':float(20*np.log10(np.max(np.abs(x)))),'rms_dbfs':float(20*np.log10(np.sqrt(np.mean(x*x)))),'seconds':len(x)/SR,'seam_delta':float(np.max(np.abs(x[0]-x[-1])))}
# 64 seconds, sparse D pentatonic. Circular overlap of note tails gives a true loop.
N=SR*64; music=np.zeros((N,2))
score=[50,57,62,64,69,66,64,62,57,62,66,64,57,54,52,50,
       50,54,57,62,66,69,64,62,57,54,62,57,54,52,57,50]
for i,midi in enumerate(score):
    t=np.arange(SR*7)/SR; freq=440*2**((midi-69)/12)
    note=np.zeros(len(t))
    for harmonic in range(1,7):
        note+=np.sin(2*np.pi*freq*harmonic*t)*np.exp(-t*(.65+.32*harmonic))/harmonic**2.1
    note*= (1-np.exp(-t/0.014))*.14
    note*=np.minimum(1,(7-t)/.2)
    pan=.15*np.sin(i*1.7); index=(np.arange(len(t))+int((i*2+.08*(i%3))*SR))%N
    for ch,gain in enumerate([.75-pan,.75+pan]):
        np.add.at(music[:,ch],index,note*gain)
        np.add.at(music[:,ch],(index+int(.19*SR))%N,note*.12)
# Soft modal wood: damped, inharmonic low resonances + low-passed contact noise.
report={}
music*=4.0
report['workshop_loop.wav']=save('workshop_loop.wav',music)
for variant in range(3):
    t=np.arange(int(.24*SR))/SR; x=np.zeros(len(t))
    for f,g,d in [(190,1,28),(423,.5,40),(781,.2,58)]:
        x+=g*np.sin(2*np.pi*f*(1+variant*.017)*t)*np.exp(-d*t)
    noise=np.convolve(rng.normal(0,1,len(t)),np.ones(25)/25,mode='same')
    x=(x+.25*noise*np.exp(-t*100))*(1-np.exp(-t/.0018))
    x*=np.minimum(1,(.24-t)/.025);x=x/max(abs(x))*.48
    report[f'wood_seat_{variant}.wav']=save(f'wood_seat_{variant}.wav',x)
subprocess.run(['ffmpeg','-y','-v','error','-i',str(OUT/'workshop_loop.wav'),'-c:a','vorbis','-strict','-2','-q:a','4',str(OUT/'workshop_loop.ogg')],check=True)
(OUT/'analysis.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))

# The PCM master is reproducible; only compressed music is shipped.
(OUT/"workshop_loop.wav").unlink()

# Very short UI feedback derived from our own wood sound (65 ms, 12 ms tail fade).
with wave.open(str(OUT/'wood_seat_0.wav'),'rb') as source:
    params=source.getparams()
    samples=np.frombuffer(source.readframes(round(SR*.065)),dtype='<i2').astype(float)
fade=round(SR*.012)
samples[-fade:]*=np.linspace(1,0,fade)
with wave.open(str(OUT/'ui_tap.wav'),'wb') as target:
    target.setparams(params);target.writeframes(samples.astype('<i2').tobytes())
