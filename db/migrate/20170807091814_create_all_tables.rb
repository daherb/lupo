# frozen_string_literal: true

class CreateAllTables < ActiveRecord::Migration[5.1]
  def change
    create_table "allocator", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
      t.string "contact_email", null: false
      t.string "contact_name", limit: 80, null: false
      t.datetime "created"
      t.integer "doi_quota_allowed", null: false
      t.integer "doi_quota_used", null: false
      t.binary "is_active", limit: 1
      t.string "name", null: false
      t.string "password"
      t.string "role_name"
      t.string "symbol", null: false
      t.datetime "updated"
      t.integer "version"
      t.text "comments", limit: 4294967295
      t.string "experiments"
      t.index ["symbol"], name: "symbol", unique: true
    end

    create_table "allocator_prefixes", primary_key: ["allocator", "prefixes"], options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
      t.integer "allocator", limit: 8, null: false
      t.integer "prefixes", limit: 8, null: false
      t.index ["allocator"], name: "FKE7FBD67446EBD781"
      t.index ["prefixes"], name: "FKE7FBD674AF86A1C7"
    end

    create_table "datacentre", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
      t.text "comments", limit: 4294967295
      t.string "contact_email", null: false
      t.string "contact_name", limit: 80, null: false
      t.datetime "created"
      t.integer "doi_quota_allowed", null: false
      t.integer "doi_quota_used", null: false
      t.string "domains"
      t.binary "is_active", limit: 1
      t.string "name", null: false
      t.string "password"
      t.string "role_name"
      t.string "symbol", null: false
      t.datetime "updated"
      t.integer "version"
      t.integer "allocator", limit: 8, null: false
      t.string "experiments"
      t.index ["allocator"], name: "FK6695D60546EBD781"
      t.index ["symbol"], name: "symbol", unique: true
    end

    create_table "datacentre_prefixes", primary_key: ["datacentre", "prefixes"], options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
      t.integer "datacentre", limit: 8, null: false
      t.integer "prefixes",  limit: 8, null: false
      t.index ["datacentre"], name: "FK13A1B3BA47B5F5FF"
      t.index ["prefixes"], name: "FK13A1B3BAAF86A1C7"
    end

    create_table "dataset", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
      t.datetime "created"
      t.string "doi", null: false
      t.binary "is_active", limit: 1, null: false
      t.binary "is_ref_quality", limit: 1
      t.integer "last_landing_page_status"
      t.datetime "last_landing_page_status_check"
      t.string "last_metadata_status"
      t.datetime "updated"
      t.integer "version"
      t.integer "datacentre", limit: 8, null: false
      t.datetime "minted"
      t.index ["datacentre"], name: "FK5605B47847B5F5FF"
      t.index ["doi"], name: "doi", unique: true
    end

    create_table "media", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
      t.datetime "created"
      t.string "media_type", limit: 80
      t.datetime "updated"
      t.string "url", null: false
      t.integer "version"
      t.integer "dataset", limit: 8, null: false
      t.index ["dataset", "updated"], name: "dataset_updated"
      t.index ["dataset"], name: "FK62F6FE44D3D6B1B"
    end

    create_table "metadata", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
      t.datetime "created"
      t.integer "metadata_version"
      t.integer "version"
      t.binary "xml", limit: 16777215
      t.integer "dataset", limit: 8, null: false
      t.binary "is_converted_by_mds", limit: 1
      t.string "namespace"
      t.index ["dataset", "metadata_version"], name: "dataset_version"
      t.index ["dataset"], name: "FKE52D7B2F4D3D6B1B"
    end

    create_table "prefix", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
      t.datetime "created"
      t.string "prefix", limit: 80, null: false
      t.integer "version"
      t.index ["prefix"], name: "prefix", unique: true
    end

    add_foreign_key "allocator_prefixes", "allocator", column: "allocator", name: "FKE7FBD67446EBD781", on_delete: :cascade
    add_foreign_key "allocator_prefixes", "prefix", column: "prefixes", name: "FKE7FBD674AF86A1C7", on_delete: :cascade
    add_foreign_key "datacentre", "allocator", column: "allocator", name: "FK6695D60546EBD781", on_delete: :cascade
    add_foreign_key "datacentre_prefixes", "datacentre", column: "datacentre", name: "FK13A1B3BA47B5F5FF", on_delete: :cascade
    add_foreign_key "datacentre_prefixes", "prefix", column: "prefixes", name: "FK13A1B3BAAF86A1C7", on_delete: :cascade
    add_foreign_key "dataset", "datacentre", column: "datacentre", name: "FK5605B47847B5F5FF", on_delete: :cascade
    add_foreign_key "media", "dataset", column: "dataset", name: "FK62F6FE44D3D6B1B", on_delete: :cascade
    add_foreign_key "metadata", "dataset", column: "dataset", name: "FKE52D7B2F4D3D6B1B", on_delete: :cascade
  end
end
