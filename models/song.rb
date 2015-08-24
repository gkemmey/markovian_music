class Song < ActiveRecord::Base
  has_and_belongs_to_many :instruments
  has_many :time_slices
end
