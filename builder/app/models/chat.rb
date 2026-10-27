# One conversation with a project's agent: its messages and the Claude session that holds
# its context, resumed on each turn. A new chat starts a new session on the app as it is.
class Chat < ApplicationRecord
  belongs_to :project, touch: true
  belongs_to :forked_from, class_name: "Chat", optional: true
  has_many :messages, -> { order(:id) }, dependent: :destroy

  normalizes :title, with: ->(title) { title.squish.presence }
  validates :title, length: { maximum: 80 }

  # The files sent in it go with it; the session's transcript stays where the agent keeps it.
  before_destroy { messages.user.each { |message| FileUtils.rm_rf(Attachment.folder(message)) } }

  # Named after what the owner first asked for in it.
  def name_after(request)
    update!(title: request.to_s.squish.truncate(80, separator: " ")) if title.blank? && request.present?
  end

  # A new chat with this one's messages (and the files sent with them) whose first turn
  # branches this chat's session (--fork-session): the agent remembers everything said here,
  # and what's said next stays out of this chat.
  def fork
    transaction do
      copy = project.chats.create!(forked_from: self, title: display_title, session_id:, session_cost_usd:, fork_session: session_id.present?)
      messages.each do |message|
        copied = copy.messages.create!(message.attributes.slice("role", "body", "data", "created_at"))
        folder = Attachment.folder(message)
        FileUtils.cp_r(folder, Attachment.folder(copied)) if message.user? && folder.exist?
      end
      copy
    end
  end

  def display_title
    title.presence || messages.user.first&.body.to_s.squish.truncate(80, separator: " ").presence || "New chat"
  end
end
