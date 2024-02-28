me.dir() + "applause.wav" => string filename;

// the patch 
SndBuf buf => dac;
SndBuf buf2 => dac;
// load the file
filename => buf.read;
filename => buf2.read;
buf.loop(1);
buf2.loop(1);

float gain1;

// fun void loopAndXFade(SndBuf @ buf) {
//   while (1::ms => now) {  // update gain every millisecond
//     // remap the playhead pos from [0, numsamples] => [-1, 1]
//     Math.remap(
//       buf.pos(),
//       0, buf.samples(), 
//       -1, 1
//     ) => float progress;
//     // map progress to triangular window with peak at x = 0
//     (1.0 - Math.fabs(progress)) => buf.gain;
//     (1.0 - Math.fabs(progress)) => gain1;
//   }
// }

// fun void loopAndXFadeComplement(SndBuf @ buf) {
//   while (1::ms => now) {  // update gain every millisecond
//     // map progress to triangular window with peak at x = 0
//     (1.0 - gain1) => buf2.gain;
//   }
// }

spork ~ loopAndXFade(buf);
1::second => now;
spork ~ loopAndXFadeComplement(buf2);

// time loop to keep everything going
while( true ) 1::second => now;