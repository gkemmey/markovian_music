require "midilib"
include MIDI

# time_from_start in miliseconds
# a beat = a quaternote
# bpm = quaternotes per minute
# microseconds per quaternote / 1000 = miliseconds per quaternote

DEFAULT_MIDI_TEST_FILE = 'NoFences.mid'

slice_sizes = {}
tempo_events = []

# read the song
seq = MIDI::Sequence.new()
File.open(DEFAULT_MIDI_TEST_FILE, 'rb') do |file|
  seq.read(file)
end

# get all tempo events
seq.tracks[0].events.each { |e| tempo_events << e if e.is_a? MIDI::Tempo }

# calcualte quater note worth at each time_from_start
tempo_events.each_with_index do |e, i|
  start_time = e.time_from_start
  end_time = tempo_events[i + 1] ? tempo_events[i + 1] : 1_000_000

  # miliseconds per quaternote for this time_from_start range of song
  slice_sizes[start_time...end_time] = e.data / 1000
end

puts slice_sizes

# TODO NEXT - Figure out what's going on at each slice of 750 miliseconds
