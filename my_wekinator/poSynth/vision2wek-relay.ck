//----------------------------------------------------------------------------
// name: face-relay.ck
// desc: relay FaceOSC messages to Wekinator
//
// get FaceOSC here (and also see the OSC message it sends)
//     https://github.com/kylemcdonald/ofxFaceTracker/releases
//
// author: Ge Wang (https://ccrma.stanford.edu/~ge/)
// date: Winter 2023
//----------------------------------------------------------------------------

// our OSC receiver (from FaceOSC)
OscIn oin;
// incoming port (from FaceOSC)
9527 => oin.port;
// our OSC message shuttle
OscMsg msg;
// listen for all message
oin.listenAll();

// destination host name
"localhost" => string hostname;
// destination port number: 6448 is Wekinator default
6448 => int port;
// our OSC sender (to Wekinator)
OscOut xmit;
// aim the transmitter at destination
xmit.dest( hostname, port );

// storage for msg
int NUM_ARGS;
float POSE[34];

// print
cherr <= "listening for messages on port " <= oin.port()
      <= "..." <= IO.newline();
      
// spork the listener
spork ~ incoming();

// main shred loop
while( true )
{
    // can do things here at a different rate
    // for now, do nothing

    // advance time
    1::second => now;
}

// listener
fun void incoming()
{
    // infinite event loop
    while( true )
    {
        // wait for event to arrive
        oin => now;
        
        // grab the next message from the queue. 
        while( oin.recv(msg) )
        {         
            // print message type
            cherr <= "RECEIVED: \"" <= msg.address <= "\": ";        
            // print arguments
            printArgs( msg );
            
            // handle message
            if ( msg.address == "/poses/arr" ) {
                msg.numArgs() => NUM_ARGS;
                POSE.reset();
                msg.getFloat(0) => float vision_width;
                msg.getFloat(1) => float vision_height;
                msg.getInt(2) => float num_poses;
                for (4 => int i; i < 3 + num_poses * 52; i++) {
                    if (i % 3 != 0) { // exclude z values
                        POSE << msg.getFloat(i);
                    }
                }
                <<<POSE.size()>>>;
            }
        }
        
        // reformat and relay message to Wekinator
        send2wek();
    }
}

// reformat and send what we want to Wekinator
fun void send2wek()
{
    // start the message...
    xmit.start( "/wek/inputs" );
    
    // print
    cherr <= "  *** SENDING: \"/wek/inputs/\": ";
    for (int i; i < POSE.size(); i++) {
        cherr <= POSE[i] <= " ";
    }
    cherr <= IO.newline();

    // add each for sending
    for (int i; i < POSE.size(); i++) {
        POSE[i] => xmit.add;
    }
    
    // send it
    xmit.send();
}

// print argument
fun void printArgs( OscMsg msg )
{
    // iterate over
    for( int i; i < msg.numArgs(); i++ )
    {
        if( msg.typetag.charAt(i) == 'f' ) // float
        {
            cherr <= msg.getFloat(i) <= " ";
        }
        else if( msg.typetag.charAt(i) == 'i' ) // int
        {
            cherr <= msg.getInt(i) <= " ";
        }
        else if( msg.typetag.charAt(i) == 's' ) // string
        {
            cherr <= msg.getString(i) <= " ";
        }            
    }       
    
    // new line
    // cherr <= IO.newline();
}
