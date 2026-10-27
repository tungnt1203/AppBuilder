# One conversation with a project's agent: its messages and the Claude session that holds
# its context, resumed on each turn. A new chat starts a new session on the app as it is.
class Chat < ApplicationRecord
  belongs_to :project, touch: true
  has_many :messages, -> { order(:id) }, dependent: :destroy

  normalizes :title, with: ->(title) { title.squish.presence }
  validates :title, length: { maximum: 80 }

  # The files sent in it go with it; the session's transcript stays where the agent keeps it.
  before_destroy { messages.user.each { |message| FileUtils.rm_rf(Attachment.folder(message)) } }

  # Named after what the owner first asked for in it.
  def name_after(request)
    update!(title: request.to_s.squish.truncate(80, separator: " ")) if title.blank? && request.present?
  end

  def display_title
    title.presence || messages.user.first&.body.to_s.squish.truncate(80, separator: " ").presence || "New chat"
  end
end
