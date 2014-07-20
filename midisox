#! /usr/bin/python3
import sys
import os
import re
import copy
import math
import fcntl
import termios
import struct
import MIDI

Version = '5.5  for Python3'
VersionDate = '20130507'

# 20130507 5.5 quantise effect gets channels too
# 20130321 5.4 bug fixed in quantise effect
# 20120626 5.3 compand effect default_gradient is 1.0 not 0.0
# 20111225 5.2 pitch effect gets channels too
# 20111224 5.1 introduce vol effect, with channels like compand
# 20111201 5.0 mixer effect with negative channel suppresses that channel
# 20111129 5.0 introduce new quantise effect and compand effect
# 20110920 4.9 fade with stop_time == 0 fades at end of file
# 20100926 4.3 bug fixed appending to tuple in mixer()
# 20100910 4.2 python version fade effect handles absent params
# 20100802 4.1 bug fixed in mixer effect
# 20100306 4.0 bug fixed in pan effect
# 20100203 3.9 pitch as synonym for key effect
# 20091128 3.8 fetches URLs as input-filenames
# 20091127 3.7 '|cmd' pipe-style input files
# 20091113 3.6 -d output-file plays through aplaymidi
# 20091112 3.5 pad shifts from 0 ticks, stat output tidied
# 20091107 3.4 mixer effect does channel-remapping e.g. 3:1
# 20091021 3.3 warns about mixing GM on and GM off or bank-select
# 20091018 3.2 stat -freq detects screen width
# 20091018 3.1 does the pan effect
# 20091018 3.0 stat effect gets the -freq option
# 20091015 2.9 does the mixer effect (channels ?)
# 20091014 2.8 echo channels get panned right and left
# 20091014 2.7 does the echo effect
# 20091013 2.6 does the key effect
# 20091013 2.5 midi2ms_score not opus2ms_score
# 20091012 2.4 uses midi2ms_score
# 20091011 2.3 fixed infinite loop in pad at the end
# 20091010 2.2 to_millisecs() must now be called on the opus
# 20091010 2.1 stat effect sorted, and more complete
# 20091010 2.0 vol_mul() improves defensiveness and clarity
# 20091010 1.9 the fade effect fades-out correctly
# 20091010 1.8 does the fade effect, and trim works with one arg
# 20091009 1.7 will read from - (i.e. stdin)
# 20091009 1.6 does the repeat effect
# 20091008 1.5 does -h, --help and --help-effect=NAME
# 20091007 1.4 does the pad effect
# 20091007 1.3 does the tempo effect
# 20091007 1.2 will write to - (i.e. stdout), and does trim
# 20091006 1.1 does sequence, concatenate and stat
# 20091003 1.0 first working version, does merge and mix

def print_help(topic='global'):
    help_dict = {
    'global': '''
midisox [global-options]  \\
   [format-options] infile1 [[format-options] infile2] ...  \\
   [format-options] outfile  \\
   [effect [effect-options]] ...

Global Options:
   -h, --help
       Show version number and usage information.
   --help-effect=NAME
       Show usage information on the specified effect (or "all").
   --interactive
       Prompt before overwriting an existing file
   -m|-M|--combine concatenate|merge|mix|sequence
       Select the input file combining method; -m means ‘mix’, -M ‘merge’
   --version
       Show version number and exit.

Input & Output Files and their Options:
   Files can be either filenames, or:
   "-" meaning STDIN or STDOUT accordingly
   "|program [options] ..."  uses the program's stdout as an input file
   "http://etc/etc"  will fetch any valid URL as an input file
   "-d" meaning the default output-device; will be played through aplaymidi
   "-n" meaning a null output-device (useful with the "stat" effect)
   There is only one file-format-option available:
   -v, --volume FACTOR
       Adjust volume by a factor of FACTOR.  A number less
       than 1 decreases the volume; greater than 1 increases it.
''',
    'compand': '''compand   gradient { channel:gradient }
    Adjusts the velocity of all notes closer to (or away from) 100.
    If the gradient parameter is 0 every note gets volume 100, if it
    is 1.0 there is no effect, if it is greater than 1.0 there is
    expansion, and if negative the loud notes become soft and the soft
    notes loud.  Individual channels can be given individual gradients.
    The syntax of this effect is not the same as its SoX equivalent.
''',
    'echo': '''echo   gain-in gain-out  <delay decay>
    Add echoing to the audio.  Each  delay decay  pair gives the
    delay in milliseconds  and the decay of that echo.  Gain-in and
    gain-out are ignored, they are there for compatibilty with SoX.
    The echo effect triples the number of channels in the MIDI, so
    doesn't work well if there are more than 5 channels initially.
    E.g.:   echo 1 1 240 0.6 450 0.3
''',
    'fade': '''fade   fade-in-length   [stop-time [fade-out-length]]
    Add a fade effect to the beginning, end, or both of the MIDI.
    Fade-ins start from the beginning and ramp the volume (specifically,
    the velocity parameter of all the notes) from zero to full over
    fade-in-length seconds. Specify 0 seconds if no fade-in is wanted.
    For fade-outs, the MIDI is truncated at stop-time, and the volume
    ramped from full down to zero, starting at fade-out-length seconds
    before the stop-time. If fade-out-length is not specified, it defaults
    to the same as fade-in-length. No fade-out is performed if stop-time
    is not specified. If the stop-time is specified as 0, it will be
    set to the end of the MIDI.  Times are specified in seconds: ss.frac
''',
    'key': '''key  shift
    Changes the key (i.e. pitch but not tempo).
    This is just a synonym for the pitch effect.
''',
    'mixer': '''mixer < channel[:to_channel] >
    Reduces the number of MIDI channels, by selecting just some
    of them and combining these (if necessary) into one track.
    The channel parameters are the channel-numbers 0...15,
    for example  mixer 9  selects just the drumkit.
    If an optional to_channel is specified, the selected channel
    will be remapped to the to_channel; for example,  mixer 3:1
    will select just channel 3 and renumber it to channel 1.
    The syntax of this effect is not the same as its SoX equivalent.
''',
    'pad': '''pad { length[@position] }
pad  length_at_start  length_at_end
    Pads the audio with silence, at the beginning, the end, or any
    specified points through the audio.  Both length and position
    are specified in seconds.  length is the amount of silence to
    insert, and position the position at which to insert it.
    Any number of lengths and positions may be specified, provided
    that each specified position is not less that the previous one.
    position is optional for the first and last lengths specified,
    and if omitted correspond to the beginning and end respectively.
    For example:   pad 1.5 1.5   adds 1.5 seconds of silence at each
    end of the MIDI,  whilst   pad 2.5@180   inserts 2.5 seconds of
    silence 3 minutes into the MIDI. If silence is wanted only at
    the end of the audio, specify a zero-length pad at the start.
''',
    'pan': '''pan  direction
    Pans all the MIDI-channels from one side to another.
    The direction is a value from -1 to 1;
    -1 represents far left and 1 represents far right.
''',
    'pitch': '''pitch  shift
    Changes the pitch (i.e. key but not tempo). shift gives the pitch
    shift as positive or negative 'cents' (i.e. 100ths of a semitone).
    However, currently, all pitch-shifts are round to the nearest 100
    cents, i.e. to the nearest semitone.
''',
    'quantise': '''quantise  length { channel:length }
    Adjusts the beginnings of all the notes to be
    a multiple of length seconds since the previous note.
    If length>30 then it is deemed to be be milliseconds.
    Channels for which length is zero do not get quantised.
    quantize is a synonym.
    This is a MIDI-related effect, and is not present in Sox.
''',
    'quantize': '''quantize  length { channel:length }
    Adjusts the beginnings of all the notes to be
    a multiple of length seconds since the previous note.
    If length>30 then it is deemed to be be milliseconds.
    Channels for which length is zero do not get quantized.
    quantise is a synonym.
    This is a MIDI-related effect, and is not present in Sox.
''',
    'repeat': '''repeat  count
    Repeat the entire MIDI "count" times. Note that repeating once
    doubles the length: the original MIDI plus the one repeat.
''',
    'stat': '''stat  [ -freq ]
    Do a statistical check on the input file, and print results on
    stderr. The MIDI is passed unmodified through the processing chain.
    The -freq option calculates the input's MIDI-pitch-spectrum 
    (60=middle-C) and prints it to stderr before the rest of the stats
''',
    'tempo': '''tempo  factor
    Change the tempo (but not the pitch).
    "factor" gives the ratio of new tempo to the old tempo.
''',
    'trim': '''trim  start [length]
    Outputs only the segment of the file starting at "start" seconds,
    and ending "length" seconds later, or at the end if length is
    not specified.  Patch-setting events, however, are preserved,
    even if they occurred before the start of the segment.
''',
    'vol': '''vol  increment { channel:increment }
    Adjusts the velocity (volume) of all notes by a fixed increment.
    If "increment" is -15 every note has its velocity reduced by
    fifteen, if it is 0 there is no effect, if it is +10 the velocity is
    increased by ten. Individual channels (0..15) can be given individual
    adjustments.  The syntax of this effect is not the same as SoX's vol.
'''
    }
    if topic == 'global':
        print('midisox version '+Version+' '+VersionDate)
        print(help_dict['global'])
        help_dict.pop('global')
        #help_dict.pop('unimplemented')
        print("Available effects:\n    "+', '.join(sorted(help_dict.keys())))
    elif topic == 'all':
        help_dict.pop('global')
        for key in sorted(help_dict.keys()):
            print(help_dict[key])
    else:
        try:
            print(help_dict[topic])
        except KeyError:
            help_dict.pop('global')
            #help_dict.pop('unimplemented')
            print("Available effects:\n    "+', '.join(sorted(help_dict.keys())))


# ----------------------- infrastructure --------------------
def warn(s):
    sys.stderr.write(str(s)+"\n")

def warning(s):
    warn('warning: '+str(s))

def die(s):
    warn(s)
    exit(1)

def vol_mul(vol=100, mul=1.0):
    new_vol = round(float(vol)*float(mul))
    if new_vol < 0:
        new_vol = 0 - new_vol
    if new_vol > 127:
        new_vol = 127
    elif new_vol < 1:
        new_vol = 1   # some synths interpret vol=0 as vol=default
    return new_vol

UsingStdinAsAFile = False
def file2millisec(filename):
    global UsingStdinAsAFile
    if filename == '-n':
        return([1000,[]])
    if filename == '-':
        if UsingStdinAsAFile:
            die("can't read STDIN twice")
        try:   # again, mixing try/except and if/else :-(
            with os.fdopen(sys.stdin.fileno(), 'rb') as fh:
                UsingStdinAsAFile = True
                midi = bytes(fh.read())
                return MIDI.midi2ms_score(midi)
        except (EnvironmentError) as err:
            die("can't read {0}: {1}".format(filename, err))
    match_object = re.search('^\|\s*(.+)', filename)
    if (match_object):
        capture_groups = match_object.groups()  # a tuple
        command = capture_groups[0]
        import subprocess
        pipe = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        midi = pipe.stdout.read()
        msg  = pipe.stderr.read()
        pipe.stdout.close()
        status = pipe.wait()
        if status:
            die("can't run {0}: {1}".format(command, msg.decode()))
        return MIDI.midi2ms_score(midi)
    match_object = re.search('^[a-z]+:/', filename)   # 3.8
    if (match_object):
        import urllib.request
        fh = urllib.request.urlopen(filename)
        midi = fh.read()
        return MIDI.midi2ms_score(midi)

    try:
        with open(filename, "rb") as fh:
            midi = bytes(fh.read())
            return MIDI.midi2ms_score(midi)
    except (EnvironmentError) as err:
        die("can't read {0}: {1}".format(filename, err))

# ------------------------- effects ---------------------------

def compand(score=None, params={'0.5'}):
    h = ', see midisox --help-effect=compand'
    if len(params) < 1:
        params = {'0.5'}
    default_gradient = None
    channel_gradient = dict()
    for param in params:
        # an if/elsif/elsif/else from the python-haters-manual :-(
        match_object = re.search('^(\d+):(-?\d+)', param)
        if (match_object):
            capture_groups = match_object.groups()  # a tuple
            channel_gradient[int(capture_groups[0])] = int(capture_groups[1])
            param = capture_groups[0]
        else:
            match_object = re.search('^-?\.?\d+$|^-?\d+\.\d*$', param)
            if (match_object):
                default_gradient = float(param)
            else:
                match_object = re.search('^(\d+):(-?[.\d]+)$', param)
                if (match_object):
                    channel_gradient[match_object[0]] = match_object[1]
                else:
                    die("compand: strange parameter "+str(param)+h)
    if default_gradient == None:
        if len(channel_gradient) > 0:
            default_gradient = 1.0
        else:
            default_gradient = 0.5
    itrack = 1
    while itrack < len(score):
        previous_note_time = 0
        for event in score[itrack]:
            if event[0] == 'note':
                gradient = default_gradient
                if channel_gradient.get(event[3]):
                    gradient = channel_gradient[event[3]]
                event[5] = 100 + round(gradient * (event[5]-100))
                if event[5] > 127:
                    event[5] = 127
                elif event[5] < 1:
                    event[5] = 1; # v=0 sometimes means v=default
            itrack = itrack + 1
    return score

def echo(score=None, params=None):
    h = ', see midisox --help-effect=echo'
    if len(params) < 4:
        die('echo needs at least 4 parameters'+h)
    if len(params)%2 == 1:
        die('echo needs an even number of parameters'+h)
    stats = MIDI.score2stats(score)
    nchannels = len(stats.get('channels_total', ()))
    if nchannels > 5:
        warning(str(nchannels)+' channels is too many for echo effect')
    echo_scores = [score,]
    iparam = 2
    iecho_score = 1
    while iparam < len(params):
        try:
            delay = round(float(params[iparam]))
        except:
            die('echo: strange delay parameter '+str(params[iparam])+h)
        iparam += 1
        try:
            decay = float(params[iparam])
        except:
            die('echo: strange decay parameter '+str(params[iparam])+h)
        if iparam < 6:
            echo_scores.append(MIDI.timeshift(copy.deepcopy(score),shift=delay))
        itrack = 1
        pan = 10 + 107*(iecho_score%2)
        while itrack < len(echo_scores[-1]):
            extra_events = []
            # pan the echo_tracks Left and Right respectively
            for event in echo_scores[iecho_score][itrack]:
                if event[0] == 'note':
                    event[5] = vol_mul(event[5], decay)
                elif event[0] == 'patch_change':
                    extra_events.append(['control_change', event[1]+6, event[2], 10, pan])
                elif event[0] == 'control_change' and event[3] == 10:
                    event[4] = pan   # would like to pop the event by daren't
            echo_scores[iecho_score][itrack].extend(extra_events)
            itrack += 1
        iparam += 1
        iecho_score += 1
        if iecho_score > 2:
            iecho_score = 1
    return MIDI.merge_scores(echo_scores)

def fade(score=None, params=None):
    try:
        fade_in_ticks = round(1000*float(params[0]))
    except:
        die('the fade effect needs a fade-in length')
    stop_time_ticks = 1000000
    if len(params) == 1:
        fade_out_ticks = fade_in_ticks
    elif len(params) > 1:
        try:
            stop_time_ticks = round(1000*float(params[1]))
        except:
            die("the fade effect's stop_time unrecognised: "+str(params[1]))
        if stop_time_ticks == 0:   # 4.9
            stats = MIDI.score2stats(score)
            stop_time_ticks = stats['nticks']
        if len(params) == 2:
            fade_out_ticks = fade_in_ticks
        else:
            try:
                fade_out_ticks = round(1000*float(params[2]))
            except:
                die("the fade effect's fade_out_time unrecognised: "+str(params[2]))

    if (fade_in_ticks+fade_out_ticks) > stop_time_ticks:
        warning('the fade-in overlaps the fade-out; see midisox --help-effect=fade')

    score = MIDI.segment(score, start_time=0, end_time=stop_time_ticks)
    itrack = 1
    while itrack < len(score):
        for event in score[itrack]:
            if event[0] == 'note':
                if event[1] < fade_in_ticks:
                    event[5] = vol_mul(event[5], event[1]/fade_in_ticks)
                if event[1] > (stop_time_ticks - fade_out_ticks):
                    event[5] = vol_mul(event[5], (stop_time_ticks-event[1]) / fade_out_ticks)
        itrack += 1
    return score

def key(score=None, params='missing'):
    h = ', see midisox --help-effect=pitch'
    if len(params) < 1:
        params = {'missing'}
    default_incr = None
    channel_incr = dict()
    for param in params:
        # an if/elsif/elsif/else from the python-haters-manual :-(
        match_object = re.search('^(\d+):([-+]?\d+)', param)
        if (match_object):
            capture_groups = match_object.groups()  # a tuple
            channel_incr[int(capture_groups[0])] = round(0.01 * float(capture_groups[1]))
        else:
            match_object = re.search('^([-+]?\d+)$', param)
            if (match_object):
                default_incr = round(0.01 * float(param))
            else:
                die("pitch: strange parameter "+str(param)+h)
    if default_incr == None:
        if len(channel_incr) > 0:
            default_incr = 0
        else:
            return score
    for track in score[1:]:
        for event in track:
            if event[0] == 'note' and event[3] != 9: # don't shift the drumkit
                incr = default_incr
                if channel_incr.get(event[3]):
                    incr = channel_incr[event[3]]
                event[4] = incr + event[4]
                if event[4] > 127:
                    event[4] = 127
                elif event[4] < 0:
                    event[4] = 0
    return score

def mixer(score=None, params=None):
    h = ', see midisox --help-effect=mixer'
    pos_params = dict({})
    neg_params = dict({})  # 5.0
    remap = dict({})
    if len(params) == 0:
        die('mixer effect needs parameters'+h)
    for param in params:
        match_object = re.search('^(\d+):(\d+)$', param)
        if (match_object):
            capture_groups = match_object.groups()  # a tuple
            #if len(capture_groups[0]) < 2:  What's that about?  3.4
            #    capture_groups.append(capture_groups[0])
            remap[int(capture_groups[0])] = int(capture_groups[1])
            pos_params[int(capture_groups[0])] = True
        else:
            match_object = re.search('^-(\d+)$', param)
            if (match_object):
                capture_groups = match_object.groups()  # a tuple
                neg_params[int(capture_groups[0])] = True
            else:
                match_object = re.search('^(\d+)$', param)
                if (match_object):
                    capture_groups = match_object.groups()  # a tuple
                    pos_params[int(capture_groups[0])] = True
                else:
                    die('mixer: unrecognised channel number '+str(param)+h)
    if (len(neg_params) > 0):  # 5.0
        # if params are mixed positive and negative then die
        if (len(pos_params) > 0):
            die("mixer channels must be either all positive or all negative")
        # if params are all negative then use the complement list
        for cha in range(0, 15):
            if (not neg_params.get(cha)):
                pos_params[cha] = True
    grepped_score = MIDI.grep(score, channels=pos_params.keys())
    itrack = 1
    while itrack < len(grepped_score):
        for event in grepped_score[itrack]:
            channel_index = MIDI.Event2channelindex.get(event[0], False)
            # warn("channel_index="+str(channel_index))
            if channel_index and remap.get(event[channel_index]) != None: # 4.1
                event[channel_index] = remap[event[channel_index]]
        itrack += 1

    return MIDI.mix_scores([grepped_score,])

def pad(score=None, params=None):
    i = 0
    while i < len(params):
        param = params[i]
        match_object = re.search('^(\d+\.?\d*)@(\d+\.?\d*)', param)
        if (match_object):
            # XXX must apply these intermediate pads after any beginning pad
            capture_groups = match_object.groups()  # a tuple
            #print(str(capture_groups), file=sys.stderr)
            from_time = round(1000 * float(capture_groups[1]))
            shift     = round(1000 * float(capture_groups[0]))
            score = MIDI.timeshift(score, shift=shift, from_time=from_time)
        else:
            try:
                shift = round(1000 * float(param))
            except ValueError:
                die('unrecognised pad parameter: '+str(param))
            if i == 0:
                score = MIDI.timeshift(score, shift=shift, from_time=0)
            elif i == len(params)-1:
                stats = MIDI.score2stats(score)
                new_end_time = shift + stats['nticks']
                itrack = 1
                mark_string = 'pad '+str(param)
                while itrack < len(score):
                    score[itrack].append(['marker',new_end_time,mark_string])
                    itrack += 1
 
            else:
                die('pad parameter "'+str(param)+'" should be either first or last')

        i += 1
    return score

def pan(score=None, params=['0']):
    try:
        direction = float(params[0])
    except ValueError:
        die("pan parameter must be [-1.0 ... 1.0], was: "+str(params[0]))
    if direction > 1.00000001 or direction < -1.00000001:
        die("pan parameter must be [-1.0 ... 1.0], was: "+str(params[0]))
    itrack = 1
    while itrack < len(score):
        extra_events = []
        for event in score[itrack]:
            if event[0] == 'control_change' and event[3] == 10:
                if direction < -0.00000001:
                    event[4] = round(event[4] * (1.0+direction))
                elif direction > 0.00000001:
                    event[4] += round((127-event[4]) * direction)
            elif event[0] == 'patch_change':
                new_pan = round(63.5 + 63.5*direction)
                extra_events.append(
                    ['control_change', event[1]+6, event[2], 10, new_pan])
        score[itrack].extend(extra_events)   # 4.0
        itrack += 1
    return score

def repeat(score=None, params=['1']):
    try:
        count = int(params[0])
    except ValueError:
        die("repeat's count parameter must be an integer: "+str(params[0]))
    scores = [score]
    i = 0
    while i < count:
        scores.append(score)
        i += 1
    return MIDI.concatenate_scores(scores)

def quantise(score=None, params=None):
    h = ', see midisox --help-effect=quantise'
    default_quantum = None
    channel_quantum = dict()
    for param in params:
        # an if/elsif/elsif/else from the python-haters-manual :-(
        match_object = re.search('^(\d+):(-?\d+)', param)
        if (match_object):
            capture_groups = match_object.groups()  # a tuple
            channel_quantum[int(capture_groups[0])] = int(capture_groups[1])
            param = capture_groups[0]
        else:
            match_object = re.search('^-?\.?\d+$|^-?\d+\.\d*$', param)
            if (match_object):
                quantum = float(param)
                if quantum < 0:
                    quantum = 0 - quantum
                if quantum < 30:
                    quantum = 1000 * quantum  # to millisecs
                default_quantum = round(quantum)
            else:
                match_object = re.search('^(\d+):(-?[.\d]+)$', param)
                if (match_object):
                    quantum = float(match_object[1])
                    if quantum < 0:
                        quantum = 0 - quantum
                    if quantum < 30:
                        quantum = 1000 * quantum  # to millisecs
                    channel_quantum[match_object[0]] = round(quantum)
                else:
                    die("quantise: strange parameter "+str(param)+h)
    if default_quantum == None:
        default_quantum = 0
    itrack = 1
    while itrack < len(score):
        # the score track appears sorted by THE END TIMES of the notes
        # but here I need them sorted by the START times ....
        track = score[itrack]
        track.sort(key=lambda e: e[1])
        # track = score[itrack].sort()
        # table.sort(score[itrack], function (e1,e2) return e1[2] < e2[2] end )
        old_previous_note_time = 0
        new_previous_note_time = 0
        k = 0
        while k < len(track):
            event = track[k]
            if event[0] == 'note':
                quantum = default_quantum
                if channel_quantum.get(event[3]):
                    quantum = channel_quantum[event[3]]
                old_this_note_time = event[1]
                dt = old_this_note_time - old_previous_note_time
                if quantum > 0: # quantum must not be zero
                    dn = round(dt/quantum)
                    event[1] = new_previous_note_time + quantum * dn
                    new_this_note_time = event[1]
                    # warn("new_this_note_time="+str(new_this_note_time))
                    # readjust non-note events to lie between the adjusted times
                    # in the same proportion as they lay between the old times
                    k2 = k - 1
                    while k2 >= 0 and track[k2][0] != 'note':
                        old_non_note_time = track[k2][1]
                        if old_this_note_time > old_previous_note_time:
                            track[k2][1] = round( new_previous_note_time +
                              (old_non_note_time - old_previous_note_time) *
                              (new_this_note_time - new_previous_note_time) /
                              (old_this_note_time - old_previous_note_time) )
                        else:
                            track[k2][1] = new_previous_note_time
                        k2 = k2 - 1
                    if dn > 0 and not channel_quantum.get(event[3]):  # 5.4,5
                        old_previous_note_time = old_this_note_time
                        new_previous_note_time = new_this_note_time
                track[k] = event
            k = k + 1
        score[itrack] = track
        itrack = itrack + 1
    return score

def stat(score=None, params=None):
    stats = MIDI.score2stats(score)
    if params and len(params)>0 and params[0] == '-freq':
        pmin = 127
        pmax = 0
        for p in stats['pitches']:
             if p < pmin:
                 pmin = p
             if p > pmax:
                 pmax = p
        nmax = 0
        p = pmax
        while p >= pmin:
            n = stats['pitches'].get(p,0)
            if nmax < n:
                nmax = n
            p -= 1
        nwidth = 1+round(math.log(float(nmax))/math.log(10))
        warn('Pitch N')
        # http://bytes.com/groups/python/607757-getting-terminal-display-size
        s = struct.pack("HHHH", 0, 0, 0, 0)
        try:
            x = fcntl.ioctl(sys.stderr.fileno(), termios.TIOCGWINSZ, s)
            [maxrows, maxcols, xpixels, ypixels] = struct.unpack("HHHH", x)
        except:
            maxcols = 80
        p = pmax
        while p >= pmin:
            n = stats['pitches'].get(p,0)
            if nmax > (maxcols-10-nwidth):
                bar = '#' * round((maxcols-10-nwidth)*n/nmax)
            else:
                bar = '#' * n
            warn(('{0: >3} {1: >'+str(nwidth)+'} '+bar).format(p,n))
            p -= 1
    for stat in sorted(stats.keys()):
        val = stats[stat]
        if stat == 'nticks':
            print('nticks: '+str(val)+'  = '+str(0.001*float(val))+' sec',
             file=sys.stderr)
        elif stat == 'patch_changes_total':
            l = []
            for patchnum in val:
                l.append(str(patchnum));
                # l.append(str(patchnum)+': '+MIDI.Number2patch.get(patchnum, ''))
            warn('patch_changes_total: {' + ', '.join(sorted(l,key=int)) + '}')
        else:
            print(str(stat) + ': ' + re.sub(': ',':',str(val)), file=sys.stderr)
    return score

def tempo(score=None, tempo=1.0):
    tempo = float(tempo)
    if tempo < 0.1:
       tempo = 0.1
    for track in score[1:]:
        for event in track:
            event[1] = round(event[1]/tempo)
            if event[0] == 'note':
                event[2] = round(event[2]/tempo)
    return score

def trim(score=None, start=None, length=None):
    start_ticks = round(1000*float(start))
    if (length):
        end_ticks = start_ticks + round(1000*float(length))
    else:
        end_ticks = 100000000000
    return MIDI.timeshift(MIDI.segment(score, start_time=start_ticks, end_time=end_ticks), start_time=1)

def vol(score=None, params='missing'):  # 5.1
    h = ', see midisox --help-effect=vol'
    if len(params) < 1:
        params = {'missing'}
    default_incr = None
    channel_incr = dict()
    for param in params:
        # an if/elsif/elsif/else from the python-haters-manual :-(
        match_object = re.search('^(\d+):([-+]?\d+)', param)
        if (match_object):
            capture_groups = match_object.groups()  # a tuple
            channel_incr[int(capture_groups[0])] = int(capture_groups[1])
        else:
            match_object = re.search('^([-+]?\d+)$', param)
            if (match_object):
                default_incr = int(param)
            else:
                die("vol: strange parameter "+str(param)+h)
    if default_incr == None:
        if len(channel_incr) > 0:
            default_incr = 0
        else:
            return score
    itrack = 1
    while itrack < len(score):
        previous_note_time = 0
        for event in score[itrack]:
            if event[0] == 'note':
                incr = default_incr
                if channel_incr.get(event[3]):
                    incr = channel_incr[event[3]]
                event[5] = incr + event[5]
                if event[5] > 127:
                    event[5] = 127
                elif event[5] < 1:
                    event[5] = 1   # v=0 sometimes means v=default
            itrack = itrack + 1
    return score

# --------------------------main -----------------------------
Possible_Combines = ['concatenate','merge','mix','sequence']
Possible_Effects = ['compand','echo','fade','key','mixer','pad','pan','pitch',
 'quantise','quantize','repeat','silence', 'stat','tempo','trim','vol']
global_options = []
input_files    = []
output_file    = [[], '']
effects        = []

# command-line options:
Interactive_mode = False
Combine_mode = 'sequence'

i = 1
while i < len(sys.argv):
    arg = sys.argv[i]
    if arg == '--interactive':
        Interactive_mode = True
    elif arg == '--version':
        print('midisox version '+Version+' '+VersionDate)
        sys.exit(0)
    elif arg == '-h' or arg == '--help':
        print_help()
        exit(0)
    elif re.search('^--help-effect=([a-z]+)', arg):
        match_object = re.search('^--help-effect=([a-z]+)', arg)  # Py :-(
        capture_groups = match_object.groups()  # a tuple
        print_help(capture_groups[0])
        exit(0)
    elif arg == '-m':
        Combine_mode = 'mix'
    elif arg == '-M':
        Combine_mode = 'merge'
    elif arg == '--combine':
        i += 1
        if i >= len(sys.argv):
            die('--combine must be followed by something')
        arg = sys.argv[i]
        if Possible_Combines.count(arg) > 0:
            Combine_mode = arg
        else:
            die('--combine must be followed by concatenate, merge, mix, or sequence')
    else:
        break
    i += 1

volume = 1.0
while i < len(sys.argv):   # loop through all files, input and output...
    arg = sys.argv[i]
    if arg == '--volume' or arg == '-v':
        i += 1
        if i >= len(sys.argv):
            die(arg + ' must be followed by a volume, and an input file')
        try:
            volume = float(sys.argv[i])
        except:
            die('-v must be followed by a number (default volume is 1.0)')

    elif Possible_Effects.count(arg) > 0:
        break
        # os.path.exists(arg) or arg == '-':   # or a pipe...
        # die('input file ' + arg + ' does not exist')   might be output...
    # it's a filename
    else:
        input_files.append([volume, arg])
        volume = 1.0
    i += 1

# then the last of these files must be the output-file; pop it
if len(input_files) < 2:
    die('midisox needs at least one input-file and one output-file')

output_file = input_files.pop()


while i < len(sys.argv):   # loop through all effects...
    arg = sys.argv[i]
    if Possible_Effects.count(arg) > 0:
        effects.append([arg])
    else:
        effects[-1].append(arg)
    i += 1

#print('Combine_mode = ' + str(Combine_mode))
#print('input_files='+str(input_files))
#print('output_file='+str(output_file))
#print('effects='+str(effects))

# read input files in, and apply the input effects
input_scores = []
gm_on_already  = ''
gm_off_already = ''
bank_already   = ''
for input_file in input_files:
    score = file2millisec(input_file[1])
    # 3.3 detect incompatible GM-modes and warn...
    stats = MIDI.score2stats(score)
    for gm_mode in stats['general_midi_mode']:
        if gm_mode == 0 and gm_on_already:
            warning(gm_on_already+' turns GM on, but '+input_file[1]+' turns it off')
        elif gm_mode > 0 and gm_off_already:
            warning(gm_off_already+' turns GM off, but '+input_file[1]+' turns it on')
        elif gm_mode > 0 and bank_already:
            warning(bank_already+' selects a bank, but '+input_file[1]+' turns GM on')
        elif gm_mode == 0:
            gm_off_already = input_file[1]
        elif gm_mode > 0:
            gm_on_already = input_file[1]
    if stats.get('bank_select', False):
        if gm_on_already:
            warning(gm_on_already+' turns GM on, but '+input_file[1]+' selects a bank')
        bank_already = input_file[1]
    volume = input_file[0]
    if volume < 0.99 or volume > 1.01:
        itrack = 1
        while itrack < len(score):
            for j in range(len(score[itrack])):
                if score[itrack][j][0] == 'note':
                    score[itrack][j][5] = vol_mul(volume, score[itrack][j][5])
            itrack += 1
    input_scores.append(score)

# combine the input score into an output score
if Combine_mode == 'merge':
    output_score = MIDI.merge_scores(input_scores)
elif Combine_mode == 'mix':
    output_score = MIDI.mix_scores(input_scores)
elif Combine_mode == 'sequence' or Combine_mode == 'concatenate':
    output_score = MIDI.concatenate_scores(input_scores)
else:
    die("unsupported combine mode: "+str(Combine_mode))

# apply effects to the output score
for effect in effects:
    if effect[0] == 'compand':
        output_score = compand(output_score, effect[1:])
    elif effect[0] == 'echo':
        output_score = echo(output_score, effect[1:])
    elif effect[0] == 'fade':
        output_score = fade(output_score, effect[1:])
    elif effect[0] == 'key' or effect[0] == 'pitch':
        output_score = key(output_score, effect[1:])
    elif effect[0] == 'mixer':
        output_score = mixer(output_score, effect[1:])
    elif effect[0] == 'pad':
        output_score = pad(output_score, effect[1:])
    elif effect[0] == 'pan':
        output_score = pan(output_score, effect[1:])
    elif effect[0] == 'quantise' or effect[0] == 'quantize':
        output_score = quantise(output_score, effect[1:])
    elif effect[0] == 'repeat':
        output_score = repeat(output_score, effect[1:])
    elif effect[0] == 'stat':
        stat(output_score, effect[1:])
    elif effect[0] == 'tempo':
        try:
            effect1 = effect[1]
        except IndexError:
            effect1 = 1.0
        output_score = tempo(output_score, effect1)
    elif effect[0] == 'trim':
        try:
            effect1 = effect[1]
        except IndexError:
            effect1 = 0
        try:
            effect2 = effect[2]
        except IndexError:
            effect2 = None
        output_score = trim(output_score, effect1, effect2)
    elif effect[0] == 'vol':
        output_score = vol(output_score, effect[1:])
    else:
        die('unrecognised effect: '+str(effect))

# open the output file and print the output score to it
if output_file[1] == '-n':
    exit(0)
if output_file[1] == '-d':
    MIDI.play_score(output_score)
    exit(0)
if output_file[1] == '-':
    # sys.stdout = os.fdopen(sys.stdout.fileno(), 'wb')
    sys.stdout.buffer.write(MIDI.score2midi(output_score))
    exit(0)
if Interactive_mode and os.path.exists(output_file[1]):
    import TermClui
    TermClui.confirm('OK to overwrite '+output_file[1]+' ?') or exit()

with open(output_file[1], "wb") as fh:   # should try and except
    fh.write(MIDI.score2midi(output_score))
