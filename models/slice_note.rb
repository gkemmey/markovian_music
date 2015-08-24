class SliceNote < ActiveRecord::Base
  belongs_to :time_slice
  belongs_to :instrument
end
