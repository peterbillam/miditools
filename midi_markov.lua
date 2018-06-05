---------------------------------------------------------------------
--     This Lua5 module is Copyright (c) 2018, Peter J Billam      --
--                       www.pjb.com.au                            --
--  This module is free software; you can redistribute it and/or   --
--         modify it under the same terms as Lua5 itself.          --
---------------------------------------------------------------------

local MIDI= require 'MIDI'

local M = {} -- public interface
M.Version = '1.0'
M.VersionDate = '27jan2018'

------------------------------ private ------------------------------
function warn(...)
    local a = {}
    for k,v in pairs{...} do table.insert(a, tostring(v)) end
    io.stderr:write(table.concat(a),' ') ; io.stderr:flush()
end
function die(...) warn(...);  os.exit(1) end
function qw(s)  -- t = qw[[ foo  bar  baz ]]
    local t = {} ; for x in s:gmatch("%S+") do t[#t+1] = x end ; return t
end

math.randomseed(os.time())
-- require 'DataDumper'
local stats  = false

local function split(s, pattern, maxNb) -- http://lua-users.org/wiki/SplitJoin
	if not s or string.len(s)<2 then return {s} end
	if not pattern then return {s} end
	if maxNb and maxNb <2 then return {s} end
	local result = { }
	local theStart = 1
	local theSplitStart,theSplitEnd = string.find(s,pattern,theStart)
	local nb = 1
	while theSplitStart do
		table.insert( result, string.sub(s,theStart,theSplitStart-1) )
		theStart = theSplitEnd + 1
		theSplitStart,theSplitEnd = string.find(s,pattern,theStart)
		nb = nb + 1
		if maxNb and nb >= maxNb then break end
	end
	table.insert( result, string.sub(s,theStart,-1) )
	return result
end

function prefix (...) return table.concat({...}, " ") end

-- local NOWORD = "\n"  -- not appropriate for midi, ie in a numeric context
local NOWORD = 199

------------------------------ public ------------------------------

local UsingStdinAsAFile = false
function M.file2millisec(filename)  -- borrowed from midisox_lua
	if filename == '-n' then return {1000,{}} end
	local midi = ""
	if filename == '-' then
		if UsingStdinAsAFile then die("can't read STDIN twice") end
		-- (sys.stdin.fileno(), 'rb') as fh: Should disable txtmode for dos
		UsingStdinAsAFile = true
		return MIDI.midi2ms_score(io.read('*all'))
	end
	if string.find(filename, '^|%s*(.+)') then  -- 4.8
		local command = string.match(filename, '^|%s*(.+)')  -- 4.8
		local err_fn = os.tmpname()
		local pipe = assert(io.popen(command..' 2>'..err_fn, 'r'))
		-- rb if windows
		midi = pipe:read('*all')
		err_fh = assert(io.open(err_fn))
		local err_msg = err_fh:read('*all')  -- 4.8
		err_fh:close()  -- 4.8
		os.remove(err_fn)
		--msg  = pipe.stderr.read()
		pipe:close()  -- 4.8
		--status = pipe:wait()  -- 4.8
		if string.len(err_msg) > 1 then
			die("can't run "..command..": "..err_msg)
		end
		return MIDI.midi2ms_score(midi)
	end
	if string.find(filename, '^[a-z]+:/') then  -- 3.8
		pcall(function() require 'curl' end)
		if not curl then pcall(function() require 'luacurl' end) end
		if not curl then
			die([[you need to install lua-curl or luacurl, e.g.:
  aptitude install liblua5.1-curl0  (or equivalent on non-debian sytems)
or, if that doesn't work:
  luarocks install luacurl]])
		end
		local midi = wget(filename)
		return MIDI.midi2ms_score(midi)
	end

	fh = assert(io.open(filename, "rb"))
	local midi = fh:read('*all')
	fh:close()
	return MIDI.midi2ms_score(midi)
end

function M.reigning_chord()  -- as midichord, but detects channels as well
	local chord = {          -- stub for testing
		absolute  = {53, 33, 68, 59}, -- ascending order
		channels  = {4, 15, 0, 3},    -- in ascending-absolute-pitch order
	}
	local abs2cha = {[33]=4, [53]=15, [59]=0, [68]=3,} -- BUT unisons ?
	table.sort(chord['absolute'])
	for i,v in ipairs(chord['absolute']) do
		chord['channels'][i] = abs2cha[v]
	end
	-- print (DataDumper(chord))
	return chord
end

function M.absolute2octavised(chord)
	-- "43,53,59,68", "5,2,3,0" -> "0,10,6,9", 43
	chord['octavised'] = {0, }
	local absolute = chord['absolute']
	for i = 2, #absolute do
		chord['octavised'][i] = absolute[i] - absolute[i-1]
	end
	return chord
end

function M.octavised2canonical(chord)  -- "0,10,6,9",43 -> "
	return chord
end

function M.incremental2absolute(incremental, chord)
	-- incremental comes from the markov chain as a string
	if type(incremental) == 'string' then
		incremental = split(incremental, ',')
	end
	local absolute = {}
	local i_new = 1
	for i_old = 1, #incremental do
		local d = incremental[i_old]
		-- must also do splits and vanishings
		if d == 'X' then -- Vanishes; do nothing, and don't increment i_new
		elseif string.match(d, '&') then  -- Splits
			local splitbits = split(d, '&')
			for i,v in ipairs(splitbits) do
				absolute[i_new] = chord['absolute'][i_old] + tonumber(v)
				i_new = i_new + 1
			end
		else
			absolute[i_new] = chord['absolute'][i_old] + tonumber(d)
			i_new = i_new + 1
		end
	end
	return absolute
end

function M.absabs2incremental(abs1, abs2)   -- XXX
	-- I need to pair the notes with their closest;
	-- I should take account of the channels,
	-- but where is my channel information ?
	-- Do I need  chord={absolute={40,55,60},channels={0,1,2}}}  arguments?
	-- BUT 40,55,60->55,60,75 is tricky :-(
	if #abs1 == #abs2 then  -- same number of voices
		local inc = {}
		for i1 = 1,#abs1 do
			local delta = abs2[i1] - abs1[i1]
			if delta < 1 then
				inc[i1] = tostring(delta)
			else
				inc[i1] = '+'..tostring(delta)
			end
		end
		return table.concat(inc, ',')
	elseif #abs1 > #abs2 then   -- some voice(s) vanished
		local nearest_in_abs1 = {}
		for i2 = 1,#abs2 do     -- find its nearest neighbour in abs1
			for i1 = 1,#abs1 do
			end                 -- now which in abs1 is left over ?
		end
	elseif #abs1 < #abs2 then   -- some voice(s) split
		local nearest_in_abs2 = {}
		for i1 = 1,#abs1 do     -- find its nearest neighbour in abs2
			for i2 = 1,#abs2 do
			end                 -- now which in abs2 is left over ?
		end
	-- We could have both splits and vanishings. Best not think about this.
	else return nil
	end
end

function M.new_markov (arg)
	local allwords
	if  type(arg) == 'function' then allwords = arg
	elseif type(arg) == 'table' then
		local i = 0
		allwords = function () ; i = i + 1 ; return arg[i] end
	end
	local input_words = 0
	local found = {0,0,0,0}
-- print('allwords() =', allwords())
	local statetab_1 = {}   -- indexed by the current word only
	local statetab_2 = {}   -- indexed by the last two words
	local statetab_3 = {}   -- indexed by the last three words
	local statetab_4 = {}   -- indexed by the last four words
	local function insert (w1, w2, w3, w4, value)
		local list1 = statetab_1[w4]
		if list1 == nil then statetab_1[w4] = {value}
		else              list1[#list1 + 1] = value
		end
		local p2 = prefix(w3, w4)
		local list2 = statetab_2[p2]
		if list2 == nil then statetab_2[p2] = {value}
		else              list2[#list2 + 1] = value
		end
		local p3 = prefix(w2, w3, w4)
		local list3 = statetab_3[p3]
		if list3 == nil then statetab_3[p3] = {value}
		else              list3[#list3 + 1] = value
		end
		local p4 = prefix(w1, w2, w3, w4)
		local list4 = statetab_4[p4]
		if list4 == nil then statetab_4[p4] = {value}
		else              list4[#list4 + 1] = value
		end
	end

	-- build table
	local w1,w2,w3,w4 = NOWORD, NOWORD, NOWORD, NOWORD   -- initialise
	for nextword in allwords do
		insert(w1, w2, w3, w4, nextword)
		w1 = w2 ; w2 = w3 ; w3 = w4 ; w4 = nextword
		input_words = input_words + 1
	end
	insert(w1, w2, w3, w4, NOWORD)

	-- generate text
	w1 = NOWORD ; w2 = NOWORD ; w3 = NOWORD ; w4 = NOWORD  -- reinitialise
	local seeds = {}
	return function (opt, ...)
		if opt == 'stats' then
			local s = "input_words="..tostring(input_words)..",  "
			for i = #found,1,-1 do
				s = s .. "found["..tostring(i).."]="..tostring(found[i]).." "
			end
			return s
		elseif opt == 'seed' then
			seeds = {...}
			for i = 1, #seeds do
				seeds[i] = tostring(seeds[i])
				if statetab_1[seeds[i]] then
					w1 = w2 ; w2 = w3 ; w3 = w4 ; w4 = seeds[i]
				end
			end
			return nil
		end
		if #seeds > 0 then  -- still some seeds left; regurgitate the seed
			local w = table.remove(seeds, 1)
			return w
		end
		local nextword
		local list2 = statetab_2[prefix(w3,w4)]
		local list3 = statetab_3[prefix(w2,w3,w4)]
		local list4 = statetab_4[prefix(w1,w2,w3,w4)]
		if list4 and #list4 > 1 then
			nextword = list4[math.random(#list4)]  -- choose a random word
			found[4] = found[4] + 1
		elseif list3 and #list3 > 1 then
			nextword = list3[math.random(#list3)]  -- choose a random word
			found[3] = found[3] + 1
		elseif list2 and #list2 > 1 then
			nextword = list2[math.random(#list2)]
			found[2] = found[2] + 1
		else
			local list1 = statetab_1[w4]
			if not list1 then return end
			nextword = list1[math.random(#list1)]
			found[1] = found[1] + 1
		end
		-- if nextword ~= NOWORD then io.stdout:write(nextword, " ") end
		-- if it's a NOWORD, we should try the next one ...
		w1 = w2 ; w2 = w3 ; w3 = w4 ; w4 = nextword
		return nextword
	end
end

return M

--[=[

=pod

=head1 NAME

midi_markov.lua - Markov-chain midi-reconstruction

=head1 SYNOPSIS

  local MA = require 'markov'
  local my_markov = MA.new_markov(input_words)
  my_markov('seed','The','European','Commission')
  for i = 1,300 do io.stdout:write(tostring(my_markov())..' ') end 
  local stats = my_markov('stats')

=head1 DESCRIPTION

Midi_markov.lua evolved from markov.lua

=head1 MUSCRIPT ?

Raw I<muscript> text would need a lot of cleaning up,
and doesn't capture many important things, including the reigning chord.

Parsed I<muscript> text might put the "/ \n %d bars ..." and the
"| \n" lines onto one 'word' so as to get at least better muscript output.
This needs a new function muscript2words()
generating also a suitable multi-line I<seed> to set up the systems,
channels, patches and clefs.
The systems and C<midi channel> commands should be done just by 
regurgitating the header up to the first new-bar,
but the channels and clefs have to be obtained by parsing.
Probably it should keep track of staves, and output all staves within each bar,
which implies running a separate Markov chain for each stave-number.

=head1 HARMONY

Maintain various harmony chains of decreasing specificity:

    1)  absolute-harmony chain, eg: 43,53,59,68 -> -1,0,+1,0
    2) octavised-harmony chain, eg: 0, 10, 6, 9 -> -1,0,+1,0
    3) canonical-harmony chain, eg: 0,  2, 3, 3 -> -1,0,0,+1 etc

where at least 2) and 3) need incremental pitch-changes, so probably 1) also.
This means the RHS is in a different format from the LHS,
and I have to convert back to LHS form in order to continue.

The root must be remembered and take no part in the markov chain,
With 2) and 3) transpositions of progressions get recognised.
With 2) and 42,53,59,68 it's 0,10,6,9 that's fed to the chain,
  and 42,53,59,68 remembered;
With 3) and 42,53,59,68 it's 0,2,3,3 that's fed to the chain,
  and 42,53,68,59 remembered (note the order!)

Probably: when 1) is recognised it is used, else 2), lastly 3)

Voices can of course vanish or appear ... how to symbolise this?

    0,2,6   -> 0,0&3,0 (= 0,2,3,3)
    0,2,3,3 -> 0,X,-1,-1 (= 0,4,4)  where X means disappear

If 3) gets used, I also need to remember the octavisations,
  in order to decanonicalise.

Another problem is that something needs to assign each new pitch
to the B<channel> used by its corresponding old pitch,
so I must remember also the channels.
How to guess the channel of an "appear" voice may be an unsolveable problem.

To know the reigning-chord, I'll need to keep track of the on-notes,
as in midichord, and their corresponding channels.

I need reigning_chord() absolute2octavised() octavised2canonical()
and incremental2absolute()

Could also store all the versions of the chord in one structure, eg:

    chord = {
      absolute  = {43, 53, 59, 68},   -- ascending order
      channels  = {4, 15, 0, 3},      -- in absolute-pitch order
      octavised = {0, 10, 6, 9},      -- all positive numbers

      canonical = {0,  2, 3, 3},           -- de-octavised
      canonicalabsolute = {43, 53, 68, 59} -- same order as canonical
      canonicalchannels = {4, 15, 3, 0},   -- same order as canonical
    }

The markov-chain keys would be
C<table.concat(chord['absolute'], ',')>
and
C<table.concat(chord['octavised'], ',')>
and
C<table.concat(chord['canonical'], ',')>

incremental2absolute() would need to know whether to use
either 'absolute' and 'channels',
or 'canonicalabsolute' and 'canonicalchannels'.
Probably it should look for an optional second argument I<is_canonical>

And B<Duration ?>

=head1 MELODY

And how to take account also of the melodic shape at the same time ?
How to pick the "melody line" automatically ?
Just the fastest-moving voice is not enough, eg. alberti-bass...
Probably need to train the melody-chain from different source-material
from that used by the harmony-chains.

The preceding section is mostly about voice-leading, or harmony changes.
If it's a single line, it's a much simpler markov-chain problem.

Should durations be separately markov'd (in milliseconds ?),
thus preserving the characteristic metre ?
Should durations also somehow be markov'd by the delta-pitch ?

Ideally, when voice-leading,
MELODY should be taken into consideration on each individual voice,
and used to influence the VOICE_LEADING choice.

=head1 RHYTHM, METRE

How to Keep the Beat ?
This needs putting things together by bars (though syncopation must be legal),
or delaying things by a sub-pulse to the next pulse.
Probably it should overrule the durations suggested by HARMONY and MELODY,
though these will be taken from the original pulse anyway -
so it's more an align-the-end-of-bar problem.

=head1 FUNCTIONS

The API only contains one function:

=over 3

=item I<local my_markov = new_markov(allwords)>

I<new_markov> returns a closure - a function that lies within a
context of local variables which implement the markov generator.
You can then call this closure with no argument,
and it will return the next suggested word.

The parameter I<allwords> can be an array of words,
or it can be another closure function (for example I<ipairs>)
and I<new_markov> will detect the argument-type and behave accordingly.

The returned closure I<my_markov> can be called in several ways:

=item I<local nextword = my_markov()>

When called with no argument (or an unrecognised argument),
the closure returns another word for you to use.

=item I<my_markov('seed','The','European','Commission')>

When called with I<'seed'> as the first argument,
then the other arguments are taken as the first word or several words
that you wish your generated text to start with.

This invocation would typically be made before the start of
the main loop, which calls I<my_markov> with no arguments.
It returns I<nil>.

In this example, the generated text will start "The European Commission",
after which it will continue selecting plausible continuations of these
three words, as usual.

=item I<my_markov('stats')>

When called with I<'stats'> as the first argument,
then it returns a string with a few statistics about how things ran:
the number of words in the input, the number of matches found in the
N=4 list, the N=3 list, the N=2 list, and the N=1 list. For example:

  input_words=11719,  found[4]=7 found[3]=16 found[2]=88 found[1]=186

This invocation would typically be made after the main loop has finished.

=back

=head1 DOWNLOAD

The source is pure lua, and available at
I<http://www.pjb.com.au/comp/lua/midi_markov.lua>

Because it uses my own additions to the standard Markov calculations,
and is subject to upredictable development with no guarantee of
backward-compatibility, it is not available on I<luarocks.org>.
But you can still install it using I<luarocks> with:

   luarocks install http://www.pjb.com.au/comp/lua/midi_markov-1.1-0.rockspec

=head1 AUTHOR

Peter J Billam, http://www.pjb.com.au/comp/contact.html

=head1 SEE ALSO

 http://www.pjb.com.au/

=cut

]=]
