-- Performance indexes for all tables

-- Users
CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_country ON users(country);
CREATE INDEX idx_users_is_lender ON users(is_lender) WHERE is_lender = TRUE;
CREATE INDEX idx_users_deleted_at ON users(deleted_at) WHERE deleted_at IS NULL;

-- Concerts
CREATE INDEX idx_concerts_date ON concerts(concert_date);
CREATE INDEX idx_concerts_country ON concerts(country);
CREATE INDEX idx_concerts_artist ON concerts(artist);

-- Rental items (most queried table)
CREATE INDEX idx_rental_items_lender_id ON rental_items(lender_id);
CREATE INDEX idx_rental_items_concert_id ON rental_items(concert_id);
CREATE INDEX idx_rental_items_status ON rental_items(status);
CREATE INDEX idx_rental_items_category ON rental_items(category);
CREATE INDEX idx_rental_items_status_category ON rental_items(status, category) WHERE status = 'active';
CREATE INDEX idx_rental_items_status_concert ON rental_items(status, concert_id) WHERE status = 'active';
CREATE INDEX idx_rental_items_created_at ON rental_items(created_at DESC);
CREATE INDEX idx_rental_items_daily_price ON rental_items(daily_price);

-- Reservations
CREATE INDEX idx_reservations_borrower_id ON reservations(borrower_id);
CREATE INDEX idx_reservations_lender_id ON reservations(lender_id);
CREATE INDEX idx_reservations_item_id ON reservations(item_id);
CREATE INDEX idx_reservations_status ON reservations(status);
CREATE INDEX idx_reservations_created_at ON reservations(created_at DESC);

-- Reviews
CREATE INDEX idx_reviews_reviewer_id ON reviews(reviewer_id);
CREATE INDEX idx_reviews_reviewee_id ON reviews(reviewee_id);
CREATE INDEX idx_reviews_reservation_id ON reviews(reservation_id);

-- Chat messages
CREATE INDEX idx_chat_messages_sender_id ON chat_messages(sender_id);
CREATE INDEX idx_chat_messages_receiver_id ON chat_messages(receiver_id);
CREATE INDEX idx_chat_messages_reservation_id ON chat_messages(reservation_id);
CREATE INDEX idx_chat_messages_created_at ON chat_messages(created_at DESC);
CREATE INDEX idx_chat_messages_unread ON chat_messages(receiver_id, read_at) WHERE read_at IS NULL;

-- Fraud flags & Reports
CREATE INDEX idx_fraud_flags_user_id ON fraud_flags(user_id);
CREATE INDEX idx_reports_reporter_id ON reports(reporter_id);
CREATE INDEX idx_reports_reported_user_id ON reports(reported_user_id);
CREATE INDEX idx_reports_status ON reports(status);
