class CreateInitialDb < ActiveRecord::Migration
  def change
    create_table :songs do |t|
      t.string          :name,              null: false
      t.string          :artist,            null: false
      t.string          :file_path,         null: false
    end
    add_index :songs, [:artist]

    create_table :instruments do |t|
      t.string          :name,              null: false
      t.integer         :midi_code,         null: false
    end
    add_index :instruments, :midi_code

    # so we know what insturments a song has--if a song has an instrument
    # that has not slice_notes associated with it at a slice, then it's resting
    create_table :instruments_songs do |t|
      t.integer         :instrument_id,     null: false
      t.integer         :song_id,           null: false
    end
    add_index :instruments_songs, [:instrument_id, :song_id]

    # time_slice of a song. slice_type defines a note type:
    # 0 = quater, other's may follow
    # start_time and end_time are time in miliseconds since start of song
    create_table :time_slices do |t|
      t.integer         :slice_type,        null: false
      t.integer         :song_id,           null: false
      t.integer         :start_time,        null: false
      t.integer         :end_time,          null: false
    end
    add_index :time_slices, [:slice_type, :time_from_start]

    # notes being played by an instrument for a given time_slice
    create_table :slice_notes do |t|
      t.integer         :time_slice_id,     null: false
      t.integer         :instrument_id,     null: false
      t.integer         :midi_code
      t.integer         :velocity
      t.boolean         :rest_note,         default: false
    end
    add_index :slice_notes, [:time_slice_id, :instrument_id]
  end
end
