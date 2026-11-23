-- ============================================================================
-- LeafLense Database – Sample / Seed Data
-- File: 05_seed_data.sql
-- Description: Realistic test data for all 11 tables. Uses explicit IDs and
--              resets sequences after insertion.
-- ============================================================================

SET search_path = leaflense, public;

-- ============================================================================
-- AdminUsers (2 rows – 'admin' role only)
-- Seeded with real bcrypt hashes via pgcrypto for immediate login testing:
--   • dr_patel       (admin) -> Admin@123
--   • agri_expert_01 (admin) -> Reviewer@123
-- ============================================================================
INSERT INTO AdminUsers (admin_id, username, password_hash, full_name, email, role) VALUES
    (1, 'dr_patel',       crypt('Admin@123',    gen_salt('bf', 12)), 'Dr. Aarav Patel', 'dr.patel@leaflense.org', 'admin'),
    (2, 'agri_expert_01', crypt('Reviewer@123', gen_salt('bf', 12)), 'Maya Lin',        'maya.lin@leaflense.org', 'admin')
ON CONFLICT (admin_id) DO UPDATE
    SET password_hash = EXCLUDED.password_hash,
        full_name     = COALESCE(AdminUsers.full_name, EXCLUDED.full_name),
        email         = COALESCE(AdminUsers.email, EXCLUDED.email),
        role          = 'admin'
  WHERE AdminUsers.password_hash LIKE '%hashed_placeholder%'
     OR AdminUsers.role::TEXT <> 'admin';

DELETE FROM AdminUsers WHERE admin_id = 3 AND username = 'data_analyst';

SELECT setval('adminusers_admin_id_seq', (SELECT COALESCE(MAX(admin_id), 0) FROM AdminUsers));

-- ============================================================================
-- Diseases (6 rows)
-- ============================================================================
INSERT INTO Diseases (disease_id, disease_name, description, symptoms) VALUES
    (1, 'Tomato Late Blight',
        'Fungal disease caused by Phytophthora infestans. One of the most destructive diseases affecting tomato and potato crops worldwide.',
        'Dark brown to black water-soaked spots on leaves, white fuzzy growth (sporangia) on undersides of leaves, rapid wilting and browning of foliage, dark lesions on stems.'),
    (2, 'Tomato Leaf Mold',
        'Caused by the fungus Passalora fulva (formerly Cladosporium fulvum). Common in greenhouse conditions with high humidity.',
        'Pale green to yellow spots on upper leaf surface, olive-green to grayish-purple velvety mold on undersides, leaves curl upward and may drop prematurely.'),
    (3, 'Potato Early Blight',
        'Caused by the fungus Alternaria solani. Affects older leaves first and progresses upward through the canopy.',
        'Dark concentric rings forming target-like spots on older leaves, yellowing around lesions, premature defoliation starting from lower leaves, dark sunken lesions on tubers.'),
    (4, 'Corn Common Rust',
        'Fungal disease caused by Puccinia sorghi. Favoured by moderate temperatures (16-23°C) and high humidity.',
        'Small reddish-brown to cinnamon-brown pustules on both upper and lower leaf surfaces, pustules rupture to release powdery spores, severe infections cause leaf yellowing and drying.'),
    (5, 'Rice Blast',
        'Caused by the fungus Magnaporthe oryzae. The most significant disease of rice globally, capable of destroying entire harvests.',
        'Diamond-shaped or elliptical lesions with gray or white centers and brown margins on leaves, neck rot at the base of panicles, node discoloration.'),
    (6, 'Healthy',
        'No disease detected – the leaf appears healthy with no visible signs of infection or nutritional deficiency.',
        'No visible symptoms of disease. Uniform green coloration, intact leaf margins, no spots, lesions, or discoloration.')
ON CONFLICT (disease_id) DO NOTHING;

SELECT setval('diseases_disease_id_seq', (SELECT COALESCE(MAX(disease_id), 0) FROM Diseases));

-- ============================================================================
-- Models (2 rows)
-- ============================================================================
INSERT INTO Models (model_id, model_name, version, confidence_threshold, is_active) VALUES
    (1, 'LeafNet-ResNet50',         'v2.1', 0.7500, TRUE),
    (2, 'CropGuard-EfficientNet',   'v1.0', 0.8000, FALSE)
ON CONFLICT (model_id) DO NOTHING;

SELECT setval('models_model_id_seq', (SELECT COALESCE(MAX(model_id), 0) FROM Models));

-- ============================================================================
-- ModelClasses (12 rows – both models support all 6 diseases)
-- ============================================================================
INSERT INTO ModelClasses (model_class_id, model_id, disease_id, class_label) VALUES
    -- LeafNet-ResNet50 (model 1)
    ( 1, 1, 1, 'tomato_late_blight'),
    ( 2, 1, 2, 'tomato_leaf_mold'),
    ( 3, 1, 3, 'potato_early_blight'),
    ( 4, 1, 4, 'corn_common_rust'),
    ( 5, 1, 5, 'rice_blast'),
    ( 6, 1, 6, 'healthy'),
    -- CropGuard-EfficientNet (model 2)
    ( 7, 2, 1, 'tomato_late_blight'),
    ( 8, 2, 2, 'tomato_leaf_mold'),
    ( 9, 2, 3, 'potato_early_blight'),
    (10, 2, 4, 'corn_common_rust'),
    (11, 2, 5, 'rice_blast'),
    (12, 2, 6, 'healthy')
ON CONFLICT (model_class_id) DO NOTHING;

SELECT setval('modelclasses_model_class_id_seq', (SELECT COALESCE(MAX(model_class_id), 0) FROM ModelClasses));

-- ============================================================================
-- Recommendations (8 rows)
-- ============================================================================
INSERT INTO Recommendations (recommendation_id, title, description, source) VALUES
    (1, 'Apply Fungicide Treatment',
        'Apply a copper-based or systemic fungicide according to label directions. Begin treatment at first sign of disease and repeat at 7-14 day intervals.',
        'State Agricultural Extension Service'),
    (2, 'Practice Crop Rotation',
        'Rotate crops with non-host plants for at least 2-3 years. Avoid planting the same family of crops in the same field consecutively.',
        'FAO Crop Management Guidelines'),
    (3, 'Use Resistant Varieties',
        'Select and plant disease-resistant cultivars appropriate for your region. Consult local seed suppliers and extension offices for recommended varieties.',
        'International Crop Research Institute'),
    (4, 'Improve Irrigation Management',
        'Avoid overhead irrigation that wets foliage. Use drip irrigation or water at the base of plants during early morning hours to allow foliage to dry.',
        'USDA Water Management Bulletin'),
    (5, 'Remove and Destroy Infected Plants',
        'Promptly remove infected plant material and destroy it by burning or deep burial. Do not compost diseased material as pathogens may survive.',
        'Plant Pathology Handbook, 5th Edition'),
    (6, 'Improve Air Circulation',
        'Space plants adequately and prune lower branches to improve airflow through the canopy. This reduces humidity around leaves and inhibits fungal growth.',
        'Greenhouse Management Best Practices'),
    (7, 'Apply Soil Treatment',
        'Treat soil with approved soil fumigants or bio-fungicides before planting. Incorporate organic matter to promote beneficial soil microorganisms.',
        'Soil Health Institute Recommendations'),
    (8, 'Consult Local Extension Service',
        'Contact your local agricultural extension office for region-specific advice, disease identification confirmation, and tailored management strategies.',
        'National Agricultural Advisory Service')
ON CONFLICT (recommendation_id) DO NOTHING;

SELECT setval('recommendations_recommendation_id_seq', (SELECT COALESCE(MAX(recommendation_id), 0) FROM Recommendations));

-- ============================================================================
-- DiseaseRecommendations (mappings – each disease gets 2-3 recommendations)
-- ============================================================================
INSERT INTO DiseaseRecommendations (disease_id, recommendation_id) VALUES
    -- Tomato Late Blight → fungicide, resistant varieties, remove infected
    (1, 1), (1, 3), (1, 5),
    -- Tomato Leaf Mold → air circulation, irrigation management, fungicide
    (2, 6), (2, 4), (2, 1),
    -- Potato Early Blight → crop rotation, fungicide, soil treatment
    (3, 2), (3, 1), (3, 7),
    -- Corn Common Rust → resistant varieties, fungicide
    (4, 3), (4, 1),
    -- Rice Blast → resistant varieties, irrigation management, extension service
    (5, 3), (5, 4), (5, 8),
    -- Healthy → no specific treatment needed
    (6, 8)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- Submissions (8 rows – mix of statuses)
-- ============================================================================
INSERT INTO Submissions (submission_id, image_path, submitted_at, status, ip_address, user_agent) VALUES
    -- 3 processed (high confidence)
    (1, '/uploads/2026/11/leaf_001.jpg', NOW() - INTERVAL '28 days', 'processed',
        '192.168.1.10', 'Mozilla/5.0 (Android; Mobile)'),
    (2, '/uploads/2026/11/leaf_002.jpg', NOW() - INTERVAL '25 days', 'processed',
        '10.0.0.45',    'LeafLense-Mobile/1.2'),
    (3, '/uploads/2026/11/leaf_003.jpg', NOW() - INTERVAL '20 days', 'processed',
        '172.16.0.88',  'Mozilla/5.0 (iPhone; Safari)'),

    -- 3 low_confidence (awaiting review)
    (4, '/uploads/2026/11/leaf_004.jpg', NOW() - INTERVAL '15 days', 'low_confidence',
        '192.168.2.20', 'LeafLense-Mobile/1.2'),
    (5, '/uploads/2026/11/leaf_005.jpg', NOW() - INTERVAL '10 days', 'low_confidence',
        '10.0.1.100',   'Mozilla/5.0 (Linux; Chrome)'),
    (6, '/uploads/2026/11/leaf_006.jpg', NOW() - INTERVAL '7 days',  'low_confidence',
        '192.168.3.5',  'Mozilla/5.0 (Windows; Edge)'),

    -- 1 reviewed
    (7, '/uploads/2026/11/leaf_007.jpg', NOW() - INTERVAL '5 days',  'reviewed',
        '10.0.2.200',   'LeafLense-Mobile/1.3'),

    -- 1 pending
    (8, '/uploads/2026/11/leaf_008.jpg', NOW() - INTERVAL '1 day',   'pending',
        '192.168.1.55', 'Mozilla/5.0 (Android; Chrome)')
ON CONFLICT (submission_id) DO NOTHING;

SELECT setval('submissions_submission_id_seq', (SELECT COALESCE(MAX(submission_id), 0) FROM Submissions));

-- ============================================================================
-- Predictions (10 rows)
-- ============================================================================
INSERT INTO Predictions (prediction_id, submission_id, model_id, disease_id, confidence_score, predicted_at, is_top_prediction) VALUES
    -- Submission 1: high-confidence → Tomato Late Blight (processed)
    ( 1, 1, 1, 1, 0.9230, NOW() - INTERVAL '28 days', TRUE),
    ( 2, 1, 1, 6, 0.0770, NOW() - INTERVAL '28 days', FALSE),

    -- Submission 2: high-confidence → Healthy (processed)
    ( 3, 2, 1, 6, 0.8850, NOW() - INTERVAL '25 days', TRUE),

    -- Submission 3: high-confidence → Corn Common Rust (processed)
    ( 4, 3, 1, 4, 0.8100, NOW() - INTERVAL '20 days', TRUE),

    -- Submission 4: low-confidence → Potato Early Blight
    ( 5, 4, 1, 3, 0.5500, NOW() - INTERVAL '15 days', TRUE),
    ( 6, 4, 1, 1, 0.4500, NOW() - INTERVAL '15 days', FALSE),

    -- Submission 5: low-confidence → Rice Blast
    ( 7, 5, 1, 5, 0.6200, NOW() - INTERVAL '10 days', TRUE),

    -- Submission 6: low-confidence → Tomato Leaf Mold
    ( 8, 6, 1, 2, 0.4800, NOW() - INTERVAL '7 days',  TRUE),

    -- Submission 7: was low-confidence, now reviewed → Tomato Late Blight
    ( 9, 7, 1, 1, 0.6900, NOW() - INTERVAL '5 days',  TRUE),

    -- Submission 8 is pending (no predictions yet)
    -- Additional prediction from inactive model (for testing model comparison)
    (10, 3, 1, 6, 0.1900, NOW() - INTERVAL '20 days', FALSE)
ON CONFLICT (prediction_id) DO NOTHING;

SELECT setval('predictions_prediction_id_seq', (SELECT COALESCE(MAX(prediction_id), 0) FROM Predictions));

-- ============================================================================
-- AdminReviews (2 rows)
-- ============================================================================
INSERT INTO AdminReviews (review_id, submission_id, admin_id, assessed_disease_id, is_correct, notes, reviewed_at) VALUES
    -- Review for submission 7: admin confirms the model was correct (Tomato Late Blight)
    (1, 7, 2, 1, TRUE,
        'Visual inspection confirms late blight infection. Classic dark water-soaked lesions visible on leaf margins.',
        NOW() - INTERVAL '4 days'),

    -- Review for submission 4: admin disagrees – model said Potato Early Blight, admin says Tomato Late Blight
    (2, 4, 2, 1, FALSE,
        'Misclassification: leaf shows late blight symptoms (water-soaked spots, fuzzy growth) rather than early blight target spots. Model may need retraining on blight variants.',
        NOW() - INTERVAL '3 days')
ON CONFLICT (review_id) DO NOTHING;

SELECT setval('adminreviews_review_id_seq', (SELECT COALESCE(MAX(review_id), 0) FROM AdminReviews));

-- ============================================================================
-- SubmissionStatusHistory (entries tracking status progression)
-- ============================================================================
INSERT INTO SubmissionStatusHistory (history_id, submission_id, old_status, new_status, changed_at, changed_by) VALUES
    -- Submission 1: pending → processed
    ( 1, 1, NULL,              'pending',          NOW() - INTERVAL '28 days', 'system'),
    ( 2, 1, 'pending',         'processed',        NOW() - INTERVAL '28 days', 'system'),

    -- Submission 2: pending → processed
    ( 3, 2, NULL,              'pending',          NOW() - INTERVAL '25 days', 'system'),
    ( 4, 2, 'pending',         'processed',        NOW() - INTERVAL '25 days', 'system'),

    -- Submission 3: pending → processed
    ( 5, 3, NULL,              'pending',          NOW() - INTERVAL '20 days', 'system'),
    ( 6, 3, 'pending',         'processed',        NOW() - INTERVAL '20 days', 'system'),

    -- Submission 4: pending → low_confidence
    ( 7, 4, NULL,              'pending',          NOW() - INTERVAL '15 days', 'system'),
    ( 8, 4, 'pending',         'low_confidence',   NOW() - INTERVAL '15 days', 'system'),

    -- Submission 5: pending → low_confidence
    ( 9, 5, NULL,              'pending',          NOW() - INTERVAL '10 days', 'system'),
    (10, 5, 'pending',         'low_confidence',   NOW() - INTERVAL '10 days', 'system'),

    -- Submission 6: pending → low_confidence
    (11, 6, NULL,              'pending',          NOW() - INTERVAL '7 days',  'system'),
    (12, 6, 'pending',         'low_confidence',   NOW() - INTERVAL '7 days',  'system'),

    -- Submission 7: pending → low_confidence → reviewed
    (13, 7, NULL,              'pending',          NOW() - INTERVAL '5 days',  'system'),
    (14, 7, 'pending',         'low_confidence',   NOW() - INTERVAL '5 days',  'system'),
    (15, 7, 'low_confidence',  'reviewed',         NOW() - INTERVAL '4 days',  'agri_expert_01'),

    -- Submission 8: pending (just created)
    (16, 8, NULL,              'pending',          NOW() - INTERVAL '1 day',   'system')
ON CONFLICT (history_id) DO NOTHING;

SELECT setval('submissionstatushistory_history_id_seq', (SELECT COALESCE(MAX(history_id), 0) FROM SubmissionStatusHistory));

-- ============================================================================
-- AuditLogs (4 sample entries)
-- ============================================================================
INSERT INTO AuditLogs (audit_id, actor, action, table_name, record_id, old_values, new_values, created_at) VALUES
    (1, 'system', 'INSERT', 'submissions', 1, NULL,
        '{"submission_id": 1, "image_path": "/uploads/2026/11/leaf_001.jpg", "status": "pending"}'::JSONB,
        NOW() - INTERVAL '28 days'),
    (2, 'system', 'STATUS_CHANGE', 'submissions', 1,
        '{"status": "pending"}'::JSONB,
        '{"status": "processed"}'::JSONB,
        NOW() - INTERVAL '28 days'),
    (3, 'system', 'INSERT', 'predictions', 1, NULL,
        '{"prediction_id": 1, "submission_id": 1, "disease_id": 1, "confidence_score": 0.9230}'::JSONB,
        NOW() - INTERVAL '28 days'),
    (4, 'agri_expert_01', 'INSERT', 'admin_reviews', 1, NULL,
        '{"review_id": 1, "submission_id": 7, "admin_id": 2, "is_correct": true}'::JSONB,
        NOW() - INTERVAL '4 days')
ON CONFLICT (audit_id) DO NOTHING;

SELECT setval('auditlogs_audit_id_seq', (SELECT COALESCE(MAX(audit_id), 0) FROM AuditLogs));

-- ============================================================================
-- Verification: Row counts
-- ============================================================================
DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM AdminUsers;           RAISE NOTICE 'AdminUsers:               % rows', v_count;
    SELECT COUNT(*) INTO v_count FROM Diseases;             RAISE NOTICE 'Diseases:                 % rows', v_count;
    SELECT COUNT(*) INTO v_count FROM Models;               RAISE NOTICE 'Models:                   % rows', v_count;
    SELECT COUNT(*) INTO v_count FROM ModelClasses;         RAISE NOTICE 'ModelClasses:             % rows', v_count;
    SELECT COUNT(*) INTO v_count FROM Recommendations;      RAISE NOTICE 'Recommendations:          % rows', v_count;
    SELECT COUNT(*) INTO v_count FROM DiseaseRecommendations; RAISE NOTICE 'DiseaseRecommendations:   % rows', v_count;
    SELECT COUNT(*) INTO v_count FROM Submissions;          RAISE NOTICE 'Submissions:              % rows', v_count;
    SELECT COUNT(*) INTO v_count FROM Predictions;          RAISE NOTICE 'Predictions:              % rows', v_count;
    SELECT COUNT(*) INTO v_count FROM AdminReviews;         RAISE NOTICE 'AdminReviews:             % rows', v_count;
    SELECT COUNT(*) INTO v_count FROM SubmissionStatusHistory; RAISE NOTICE 'SubmissionStatusHistory:  % rows', v_count;
    SELECT COUNT(*) INTO v_count FROM AuditLogs;            RAISE NOTICE 'AuditLogs:                % rows', v_count;
    RAISE NOTICE '--- Seed data loaded successfully ---';
END $$;

-- ============================================================================
-- END OF FILE
-- ============================================================================
