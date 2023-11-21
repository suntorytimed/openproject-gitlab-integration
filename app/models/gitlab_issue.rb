#-- encoding: UTF-8

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2023 Ben Tey
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
# Copyright (C) 2012-2021 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See docs/COPYRIGHT.rdoc for more details.
#++

class GitlabIssue < ApplicationRecord
  LABEL_KEYS = %w[color title].freeze

  has_and_belongs_to_many :work_packages
  belongs_to :gitlab_user, optional: true

  enum state: {
    opened: 'opened',
    closed: 'closed'
  }

  validates_presence_of :gitlab_html_url,
                        :number,
                        :repository,
                        :state,
                        :title,
                        :gitlab_updated_at
  validates_presence_of :body,
                        unless: :partial?
  validate :validate_labels_schema

  scope :without_work_package, -> { left_outer_joins(:work_packages).where(work_packages: { id: nil }) }

  def self.find_by_gitlab_identifiers(id: nil, url: nil, initialize: false)
    raise ArgumentError, "needs an id or an url" if id.nil? && url.blank?

    found = where(gitlab_id: id).or(where(gitlab_html_url: url)).take

    if found
      found
    elsif initialize
      new(gitlab_id: id, gitlab_html_url: url)
    end
  end

  def partial?
    [body].all?(&:nil?)
  end

  private

  def validate_labels_schema
    return if labels.nil?
    return if labels.all? { |label| label.keys.sort == LABEL_KEYS }

    errors.add(:labels, 'invalid schema')
  end

  def with_logging
    yield if block_given?
  rescue StandardError => e
    Rails.logger.error "Error at gitlab issue: #{e} #{e.message}"
    raise e
  end
end
