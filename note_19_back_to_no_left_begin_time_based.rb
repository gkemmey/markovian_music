require "midilib"
include MIDI
 
@notes = []  # all the note events from read in songs
@on_notes = []  # just the note on events and their duration
@new_notes = []  # notes for the new song
@table = {}  # hash table of probabilities
@note_counts = {}  # number of times each note is played


def read_song (song, track_index)
  seq = MIDI::Sequence.new()
  File.open(song, 'rb') do | file |
    seq.read(file) do | track, num_tracks, i |
      unless track.nil?
        if i == track_index
          track.quantize '32nd'
          track.each do |e|
            if e.class == MIDI::NoteOn or e.class == MIDI::NoteOff
              @notes.push e
            end
          end
        end
      end
    end
  end
end

# situations to handle:  rests, chords, and "staggered chords" (ignore for now)
# to simplify chords, if multiple notes start at the same time, assume they have the same duration
# to simplify rests, if whole at the same time as three quarters, this will look like one chord + two notes + rest
# current_notes is usually only one note, but could be several notes if this is a chord; it will reset with every new "chord"
def pair_notes
  last_off_time = -1  # used to look for rests
  
  i = 0
  while i < @notes.length
    notes_to_skip = 1  # normally advance one note each time through loop, but more if chord
    
    if @notes[i].class == MIDI::NoteOn
      #puts "ON NOTE"
      
      unless last_off_time > 0 and @notes[i].time_from_start == last_off_time
        duration = @notes[i].time_from_start - last_off_time
        @on_notes.push 'x' + duration.to_s + 'xrest'
        #puts "pushed"
      end
      
      # determine the duration by looking for the note off event
      still_looking_for_off_note = true
      j = i + 1
      while still_looking_for_off_note do
        if @notes[j].note == @notes[i].note and @notes[j].channel == @notes[i].channel
          still_looking_for_off_note = false
          duration = @notes[j].time_from_start - @notes[i].time_from_start
          last_off_time = @notes[j].time_from_start
        end
        j += 1
      end
      
      current_notes = 'x' + duration.to_s + 'x' + @notes[i].note.to_s  # same duration for all notes in chord
      
      # look ahead for all notes in same chord
      # it's unintentional, but this will essentially skip off notes if on-off-on-off-etc because of the way it looks for chords
      all_notes_in_chord_found = false
      k = i + 1
      while not all_notes_in_chord_found and k < @notes.length
        @notes[i].time_from_start == @notes[k].time_from_start ?
              current_notes += 'x' + @notes[k].note.to_s :
              all_notes_in_chord_found = true if @notes[k].class == MIDI::NoteOn
              
        # now that we've dealt with this note, skip it next time through the main loop, but
        # don't skip a note if it's not in this chord--we want to deal with it when we get back to the top of the main loop
        notes_to_skip += 1 unless all_notes_in_chord_found
        
        k += 1
      end
      
      @on_notes.push current_notes
    end
    
    i += notes_to_skip
  end
end


# clears the @notes array and then processes the track
def process_track (song, track_index)
  @notes = []
  read_song(song, track_index)
  pair_notes
end


def add_note(note, next_note)
  @table[note] ||= {}
  @table[note][next_note] ||=0
  @table[note][next_note] +=1
  @note_counts[note] ||= 0
  @note_counts[note] += 1
end


def generate_table
  for x in 0..@on_notes.length-2 do  # last one is special
    add_note(@on_notes[x].to_sym, @on_notes[x+1])
  end
  add_note(@on_notes.last.to_sym, :xend)
end


def select_first_note
  max = 0
  max_note = nil
  
  @note_counts.each_pair do |k,v|
    if v > max
      max = v
      max_note = k
    end
  end
  
  max_note
end


def get_note(note)
  split = note.to_s.split 'x'
  if split[2] == 'rest'
    index = rand(@note_counts[@new_notes[@new_notes.length - 2]]) + 1
    index_so_far = 0
  
    @table[@new_notes[@new_notes.length - 2]].each_pair do |k, v|
      index_so_far += v
      return k if index_so_far >= index
    end
  else
    index = rand(@note_counts[note]) + 1
    index_so_far = 0
  
    @table[note].each_pair do |k, v|
      index_so_far += v
      return k if index_so_far >= index
    end
  end
end


def generate_new_song(max_notes = 1000)
  while @new_notes.length < max_notes and @new_notes.last != :xend
    @new_notes << get_note(@new_notes.last).to_sym
  end
end


# todo need to make sure I'm doing delta time correctly, taking into account bpm
def write_notes
  seq = Sequence.new()

  # create a first track for the sequence--this holds tempo events and stuff like that
  track = Track.new(seq)
  seq.tracks << track
  track.events << Tempo.new(Tempo.bpm_to_mpq(120))  # todo figure out from song samples
  track.events << MetaEvent.new(META_SEQ_NAME, 'Gray Kemmey')

  # create a track to hold the notes--add it to the sequence.
  track = Track.new(seq)
  seq.tracks << track

  # give the track a name and an instrument name (optional)
  track.name = 'My New Track'
  track.instrument = GM_PATCH_NAMES[0]

  # add a volume controller event (optional)
  track.events << Controller.new(0, CC_VOLUME, 127)
  
  track.events << ProgramChange.new(0, 1, 0)
  
  rest_time = 0
  
  for i in 0..@new_notes.length-1 do
    note = @new_notes[i].to_s.split 'x'
    delta_time = seq.length_to_delta((note[1].to_f / 1000.0) / 0.5)
    
    if note[2] == 'rest'
      rest_time = seq.length_to_delta((note[1].to_f / 1000.0) / 0.5)
    else
      for j in 2..note.length-1 do  # multiple notes if it is a chord
        track.events << NoteOnEvent.new(0, note[j].to_i, 127, rest_time)
        track.events << NoteOffEvent.new(0, note[j].to_i, 127, delta_time) 
      end
      
      rest_time = 0
    end
  end

  File.open(Time.now.strftime("midi_%Y%m%d_%H%M%S.mid"), 'wb') do | file | 
    seq.write(file)
  end
end


#----------- begin -------------

process_track 'bach_846.mid', 2
process_track 'bach_847.mid', 2
process_track 'bach_850.mid', 2

generate_table
@new_notes << select_first_note
generate_new_song 2000
write_notes