require "active_record"
require "sqlite3"
require "tempfile"

# A real temp file (not ":memory:") so every thread's connection shares the
# same database -- SQLite's ":memory:" is per-connection and would silently
# give each thread its own empty DB under ActiveRecord's connection pool.
db_file = Tempfile.new(["reservation_challenge", ".sqlite3"])
ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: db_file.path,
  pool: 20,     # comfortably more than the 10 concurrent threads below
  timeout: 5000 # ms; let concurrent writers queue instead of erroring
)

ActiveRecord::Schema.define do
  create_table :products do |t|
    t.string  :name, null: false
    t.integer :stock, null: false, default: 0
  end

  create_table :reservations do |t|
    t.integer :product_id, null: false
    t.integer :quantity, null: false
    t.string  :idempotency_key, null: false
    t.timestamps
  end
  add_index :reservations, :idempotency_key, unique: true
end

class Product < ActiveRecord::Base
end

class Reservation < ActiveRecord::Base
end

ReservationResult = Struct.new(:reservation, :error) do
  def success?
    error.nil?
  end
end

# ReservationService reserves units of a product's stock, safely under
# concurrent access and idempotently under retries.
# Fill in the two TODOs below.
class ReservationService
  # TODO 1: reserve! orchestrates a single reservation attempt.
  #
  # - If a Reservation already exists for this idempotency_key, return it
  #   (success) without touching stock again -- callers may retry safely.
  # - Otherwise, try to claim the stock via decrement_stock!.
  #   - If there isn't enough stock, return a failure ReservationResult.
  #   - If the decrement succeeds, create the Reservation record and
  #     return it wrapped in a successful ReservationResult.
  # - Handle the race where two requests carrying the SAME idempotency_key
  #   both pass the "does it exist?" check before either has created the
  #   row -- only one create should win. The unique index on
  #   idempotency_key is there to help you (think about what happens to
  #   the loser, and what you should do about the stock it already
  #   claimed).
  def self.reserve!(product_id:, quantity:, idempotency_key:)
  end

  # TODO 2: decrement_stock! atomically reduces a product's stock by
  # `quantity`, but only if enough stock remains -- and must be safe when
  # called concurrently from multiple threads against the same product
  # row. Return true on success, false if there wasn't enough stock.
  #
  # Hint: think about what a single SQL UPDATE with a WHERE guard buys you
  # versus reading stock into Ruby, checking it, and writing it back.
  def self.decrement_stock!(product_id, quantity)
  end
end

# --- already written: do not modify below this line ---

if __FILE__ == $PROGRAM_NAME
  product = Product.create!(name: "Limited Edition Widget", stock: 5)

  results = Queue.new

  # Ten concurrent attempts at five units of stock -- exactly five should
  # succeed, five should fail, and stock should land at exactly zero.
  threads = 10.times.map do |i|
    Thread.new do
      result = ReservationService.reserve!(
        product_id: product.id,
        quantity: 1,
        idempotency_key: "request-#{i}"
      )
      results << [i, result]
    end
  end
  threads.each(&:join)

  succeeded = 0
  10.times do
    i, result = results.pop
    if result.success?
      succeeded += 1
      puts "request-#{i}: reserved"
    else
      puts "request-#{i}: failed (#{result.error})"
    end
  end

  product.reload
  puts "---"
  puts "final stock: #{product.stock}"
  puts "successful reservations: #{succeeded}"
  puts(product.stock == 0 && succeeded == 5 ? "PASS: no overselling, no lost stock" : "FAIL: check your locking")

  # Retry safety: the same idempotency_key fired twice must only claim
  # once. Top up stock by one unit first so there's room to observe this
  # cleanly.
  product.update!(stock: product.stock + 1)
  retry_result_1 = ReservationService.reserve!(
    product_id: product.id, quantity: 1, idempotency_key: "duplicate-request"
  )
  retry_result_2 = ReservationService.reserve!(
    product_id: product.id, quantity: 1, idempotency_key: "duplicate-request"
  )
  puts "---"
  puts "retry test: first success=#{retry_result_1.success?}, second success=#{retry_result_2.success?}"
  puts "stock after retries: #{product.reload.stock} (should be 0 -- one claim, not two)"
end
