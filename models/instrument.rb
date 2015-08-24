class Instrument < ActiveRecord::Base
  has_many :slice_notes
end
