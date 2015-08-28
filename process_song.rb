require_relative File.join File.dirname(__FILE__), 'config/loader.rb'

class SongProcessor
  class SongExistsError < StandardError
  end

  # TODO - debug, decide what these should really be
  attr_reader :slice_sizes

  # options[:name] = set a name or use file_path
  def initialize(file_path, artist, options={})
    name = options[:name] || File.basename(file_path)
    name = name.downcase
    artist = artist.downcase

    Song.delete_all # TODO - debug, remove later
    if Song.exists? name: name.downcase, artist: artist.downcase
      raise SongExistsError.new("Song #{name} by #{artist} already exists")
    end

    unless File.exist? file_path
      File.open(file_path, 'rb') # raise the normal error
    end

    @song = Song.create file_path: file_path, artist: artist, name: name
    @seq = MIDI::Sequence.new()

    File.open(file_path, 'rb') do |file|
      @seq.read(file)
    end

    calc_slice_sizes
  end

  private

    def calc_slice_sizes
      @slice_sizes = {}
      tempo_events = []

      # get all tempo events
      @seq.tracks[0].events.each { |e| tempo_events << e if e.is_a? MIDI::Tempo }

      # calcualte quater note worth at each time_from_start
      tempo_events.each_with_index do |e, i|
        start_time = e.time_from_start
        end_time = tempo_events[i + 1] ? tempo_events[i + 1] : 1_000_000

        # miliseconds per slice note for this time_from_start range of song
        # e.data = microseconds per quaternote -- dividy by 1000 = miliseconds per quaternote
        @slice_sizes[start_time...end_time] = (e.data / 1000)
      end
    end

    def select_instrument(track)
      program = track.events.find { |e| e.is_a? MIDI::ProgramChange }.program

      unless Instrument.exists? midi_code: program
        Instrument.create name: program.to_s, midi_code: program
      end

      Instrument.find_by midi_code: program
    end

    def process_track(track)
      instrument = select_instrument track

      # we only care about NoteOn events at this point--time to find out
      # what's palying
      note_on_events = track.events.select { |e| e.is_a? MIDI::NoteOn }

      note_index = 0
      while note_index < note_on_events.length
        break
      end
    end
end

# ------------------------ begin ------------------------
sp = SongProcessor.new(File.join(ROOT, "songs/NoFences.mid"), 'midilib')
puts sp.slice_sizes
