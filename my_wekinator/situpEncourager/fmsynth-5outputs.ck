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

me.dir() + "applause.wav" => string filename;

// the patch 
SndBuf buf => dac;
// load the file
filename => buf.read;
0 => buf.gain;
buf.loop(1);


// ----- OSC stuff -----
// create our OSC receiver
OscIn oscin;
// a thing to retrieve message contents
OscMsg msg;
// use port 12000 (default Wekinator output port)
12000 => oscin.port;

// listen for "/wek/output" message with 5 floats coming in
oscin.addAddress( "/wek/outputs, ff" );
// print
<<< "listening for OSC message from Wekinator on port 12000...", "" >>>;
<<< " |- expecting \"/wek/outputs\" with 2 continuous parameters...", "" >>>; 

// expecting 5 output dimensions
2 => int NUM_PARAMS;
float p[NUM_PARAMS];
0 => int situp_ctr;

0 => int up;
0 => int down;

fun void waitForEvent()
{
    // infinite event loop
    while( true )
    {
        // array to hold params
        // wait for OSC message to arrive
        oscin => now;

        // grab the last message from the queue. 
        while ( oscin.recv(msg) ){
            for( int i; i < NUM_PARAMS; i++ )
            {
                if( msg.typetag.charAt(i) == 'f' ) // float
                {
                    msg.getFloat(i) => p[i];
                    // cherr <= p[i] <= " ";
                }
                else if( msg.typetag.charAt(i) == 'i' ) // int
                {
                    msg.getFloat(i) => p[i];
                    // cherr <= p[i] <= " ";
                }
            }   


            if (p[0] > 0.8) {
                // <<<p[0]>>>;
                1 => up;
            }      
            if (p[0] < 0.3) {
                // <<<p[0]>>>;
                1 => down;
                0 => up;
            }
            if (up && down) {
                situp_ctr++;
                cherr <= situp_ctr <= "\n";
                0 => up;
                0 => down;
            }
            p[0] * (p[1] - 1) => buf.gain;
        }

        // <<<situp_ctr>>>;
    }
}

// spork osc receiver loop
spork ~waitForEvent();

// time loop to keep everything going
while( true ) 1::second => now;
