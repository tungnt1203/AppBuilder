class CreateAgentAccess < ActiveRecord::Migration[8.1]
  def change
    # The keys AI agents use for the shop's agent API (/agent/v1), stored as digests.
    add_column :stores, :storefront_agent_key_digest, :string
    add_column :stores, :merchant_agent_key_digest, :string

    # The cart an AI shopping agent fills for one of its sessions.
    add_column :carts, :agent_session_key, :string
    add_index :carts, :agent_session_key, unique: true

    # What the merchant agent proposes; nothing changes in the shop until it's applied.
    create_table :agent_changes do |t|
      t.string :kind, null: false
      t.string :status, null: false, default: "staged"
      t.string :summary, null: false
      t.json :payload, null: false, default: {}
      t.json :items, null: false, default: []
      t.json :guardrail_notes, null: false, default: []
      t.string :created_by, null: false
      t.string :created_by_kind, null: false, default: "agent"
      t.string :applied_by
      t.datetime :applied_at
      t.string :discarded_by
      t.string :discarded_by_kind
      t.datetime :discarded_at

      t.timestamps
    end
    add_index :agent_changes, [ :status, :created_at ]
  end
end
