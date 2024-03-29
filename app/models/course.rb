class Course < ApplicationRecord
  belongs_to :discipline
  has_many :sections
  has_many :teachers, through: :sections
  has_many :purchases, through: :sections

  validates :course_number, presence: true
  validates :name, presence: true
  validates :area, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validate :course_number_is_unique

  def mark_deleted
    update_attribute(:is_deleted, true)
    sections.each { |s| s.mark_deleted }
  end

  def self.active_courses
    self.where(is_deleted: false)
  end

  def active_sections
    Section.where(is_deleted: false, course_id: id)
  end

  def course_number_is_unique
    if Course.where.not(id: id).find_by(course_number: course_number, is_deleted: false)
      errors.add(:course_number, "has already been taken")
    end
  end
end
