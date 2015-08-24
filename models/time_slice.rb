class TimeSlice < ActiveRecord::Base
  belongs_to :song
  has_many :slice_notes
end
