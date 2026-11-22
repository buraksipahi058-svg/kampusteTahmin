-- bets.proposed_option_id → bet_options yabancı anahtarı, bets ile bet_options arasında ikinci bir
-- ilişki yaratıyordu; PostgREST'te `bets?select=...,bet_options(...)` gömmesi belirsizleşir (PGRST201) ve
-- istemcilerin bahis sorguları bozulur. Seçeneğin aynı bahse ait olduğu submit_social_result içinde
-- zaten denetlendiği için kısıt kaldırılır.
alter table public.bets drop constraint bets_proposed_option_same_bet;
