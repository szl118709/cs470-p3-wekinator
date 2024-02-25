//----------------------------------------------------------------------------
/*  5-parameter FM synth by Jeff Snyder
    wekinator mod by Rebecca Fiebrink (2009-2015)
    updated by Ge Wang (2023)
    
    USAGE: This example receives Wekinator "/wek/outputs/" messages
    over OSC and maps incoming parameters to musical parameters;
    This example is designed to run with a sender, which can be:
    1) the Wekinator application, OR
    2) another Chuck/ChAI program containing a Wekinator object
    
    This example expects to receive 5 continuous parameters in the
    range [0,1]; these parameters are mapped to musical parameters
    in map2sound().
	
    SOUND: this uses FM synthesis:
    * generates a sawtooth wave (carrier)
    * which is frequency-modulated by a sine wave (modulator)
    * which then gets put through a low-pass filter
    * and has an amplitude envelope

    This example is "always on" -- no note triggering with keyboard
    
    expected parameters for this class are:
    0 = midinote pitch of Sawtooth oscillator (carrier freq)
    1 = lowpass filter cutoff frequency
    2 = Master gain (carrier gain)
    3 = fm oscillator midinote pitch (modulator freq)
    4 = fm oscillator index (modulator index) */
//----------------------------------------------------------------------------

// quarter note duration
0.35::second => dur playing_time;
0.2::second => dur waiting_time;
// pitch of third note in power chord (try 0, -12, 12)
0  => int OFFSET;
// controls the attack; set to 0 for hevymetl attack
1 => int USE_ENV;
// set to 0 for clean chords; 1 for feedback echo
1 => int DO_ECHO;

0.8 => float vel;
0 => int curr_chord;
//  1. G: DGBB        2. G4:DGCC         3. C:CEGC        4. D:DF#AA        5. C9:CEGD          6
[[50, 55, 59, 59], [50, 55, 60, 60], [48, 52, 55, 60], [50, 54, 57, 57], [48, 52, 55, 62], [0, 0, 0, 0] ]@=> int chords[][];
4 => int numNotes;

// patch
HevyMetl h[numNotes];
// high pass (for echoes)
HPF hpf[numNotes];
// reverb
NRev r => dac; .5 => dac.gain;
// reverb mix
0.1 => r.mix;

// FM operator envelope indices
[31,31,31,31] @=> int attacks[]; // [18,14,15,15] from patch
[31,31,31,31] @=> int decays[];  // [31,31,26,31] from patch
[15,15,15,10] @=> int sustains[]; // [15,15,13,15] from patch
[31,31,31,31] @=> int releases[]; // [8,8,8,8] from patch

// connect
for( int i; i < numNotes; i++ )
{
    h[i] => r;
    // set high pass
    600 => hpf[i].freq;
    
    // LFO depth
    0.0 => h[i].lfoDepth;
    
    if( USE_ENV)
    {
        // ops
        for( 0=>int op; op < numNotes; op++ )
        {
            h[i].opADSR( op,
            h[i].getFMTableTime(attacks[op]),
            h[i].getFMTableTime(decays[op]),
            h[i].getFMTableSusLevel(sustains[op]),
            h[i].getFMTableTime(releases[op]) );
        }
    }
}


fun void playChord()
{
    // set the pitches
    for( 0 => int i; i < numNotes; i++ ) {
        Std.mtof(chords[curr_chord][i]) => h[i].freq;
    }
    
    // note on
    for( 0 => int i; i < numNotes; i++ )
    { vel => h[i].noteOn; }
    // sound
    0.85*(playing_time) => now;
    
    // note off
    for( 0 => int i; i < numNotes; i++ )
    { 1 => h[i].noteOff; }
    // let ring
    0.15*(playing_time) => now;
}


// ----- OSC stuff -----
// create our OSC receiver
OscIn oscin;
// a thing to retrieve message contents
OscMsg msg;
// use port 12000 (default Wekinator output port)
12000 => oscin.port;

// listen for "/wek/output" message with 5 floats coming in
oscin.addAddress( "/wek/outputs, fff" );
// print
<<< "listening for OSC message from Wekinator on port 12000...", "" >>>;
<<< " |- expecting \"/wek/outputs\" with 2 continuous parameters...", "" >>>; 

// expecting 5 output dimensions
3 => int NUM_PARAMS;
float myParams[NUM_PARAMS];

// envelopes for smoothing parameters
// (alternately, can use slewing interpolators; SEE:
// https://chuck.stanford.edu/doc/examples/vector/interpolate.ck)
Envelope envs[NUM_PARAMS];
for( 0 => int i; i < NUM_PARAMS; i++ )
{
    envs[i] => blackhole;
    .5 => envs[i].value;
    10::ms => envs[i].duration;
}

// set the latest parameters as targets
// NOTE: we rely on map2sound() to actually interpret these parameters musically
fun void setParams( float params[] )
{
    // make sure we have enough
    if( params.size() >= NUM_PARAMS )
    {		
        // adjust the synthesis accordingly
        0.0 => float x;
        for( 0 => int i; i < NUM_PARAMS; i++ )
        {
            // get value
            params[i] => x;
            x => myParams[i];
            // clamp it
            if( x < 0 ) 0 => x;
            if( x > 1 ) 1 => x;
            // set as target of envelope (for smoothing)
            x => envs[i].target;
            // remember
        }
    
        // mappings
        myParams[0] $ int - 1 => curr_chord;
        <<< curr_chord >>>;
        myParams[2] * 0.5 => vel;
        // 10::ms => now;
    }

}


fun void waitForEvent()
{

    // infinite event loop
    while( true )
    {
        // array to hold params
        float p[NUM_PARAMS];

        // wait for OSC message to arrive
        oscin => now;

        // 0 => float msg_count;
        // grab the last message from the queue. 
        while( oscin.recv(msg) ){
            for( int i; i < NUM_PARAMS; i++ )
            {
                if( msg.typetag.charAt(i) == 'f' ) // float
                {
                    msg.getFloat(i) => p[i];
                    // 1 +=> msg_count;
                    cherr <= p[i] <= " ";
                }
                else if( msg.typetag.charAt(i) == 'i' ) // int
                {
                    msg.getFloat(i) => p[i];
                    // 1 +=> msg_count;
                    cherr <= p[i] <= " ";
                }
                else if( msg.typetag.charAt(i) == 's' ) // string
                {
                    cherr <= msg.getString(i) <= " ";
                }                
            }         
        }
        // <<<msg_count>>>;
        // <<<p>>>;
        // for( int i; i < NUM_PARAMS; i++ ) {
        //     <<<p[i]>>>;
        //     msg_count /=> p[i];
        //     Math.round(p[i]) => p[i];
        // }

        setParams( p );

        spork ~ playChord();
        waiting_time => now;
    }
}

// spork osc receiver loop
spork ~waitForEvent();
// // spork mapping function
// spork ~map2sound();	

// time loop to keep everything going
while( true ) 1::second => now;
