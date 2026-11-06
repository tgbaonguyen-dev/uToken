import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';

/// M08 · Insight Detail (Active State UI)
/// Triển khai chuẩn 1:1 theo Figma Inspector (Node ID: 94-3849 & 94-3851)
class InsightDetailScreen extends StatelessWidget {
  const InsightDetailScreen({
    super.key,
    this.onBack,
    this.onMarkReviewed,
  });

  final VoidCallback? onBack;
  final VoidCallback? onMarkReviewed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background, // #090A0B
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top App Bar
            _buildAppBar(context),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    // Insight Title
                    Text(
                      'Large context is driving token growth',
                      style: GoogleFonts.beVietnamPro(
                        color: const Color(0xFFF4F4F5),
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Insight Meta (Width: 350px, Height: 20px, Top: 164px, Left: 20px)
                    // Font: Be Vietnam Pro, Medium 500, 11px, Line height 18px, Color #6E6E73
                    SizedBox(
                      width: 350,
                      height: 20,
                      child: Text(
                        'Gemini · Project Camellia · Last 30 days',
                        style: GoogleFonts.beVietnamPro(
                          color: const Color(0xFF6E6E73),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          height: 18 / 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Impact Summary Card (Width: 350px, Height: 106px, Radius: 18px, Background: #121519, Border: #2A2F36)
                    _buildImpactSummaryCard(),

                    const SizedBox(height: 20),

                    // Evidence Section (Container: Width: 350px, Height: 122px, Radius: 18px, Background: #121519, Border: #2A2F36)
                    _buildEvidenceSection(),

                    const SizedBox(height: 20),

                    // Recommendation Section
                    _buildRecommendationSection(),

                    const SizedBox(height: 20),

                    // Mark as reviewed Button (Width: 350px, Height: 48px, Radius: 14px, Color: #171717, Drop Shadow)
                    _buildActionButton(),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom Navigation
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Back Button (# PROTO / Back)
          // Width: 46px, Height: 46px, Radius: 23px, Color: #121519
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onBack ?? () => Navigator.maybePop(context),
              borderRadius: BorderRadius.circular(23),
              child: Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF121519),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF2A2F36).withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.chevron_left,
                  size: 28,
                  color: Color(0xFFF4F4F5), // hoặc glyph trắng sáng rõ ràng trên nền #121519
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Header Text: 'Insight detail', font Be Vietnam Pro, SemiBold 600, 22px, #F4F4F5
          Expanded(
            child: Text(
              'Insight detail',
              style: GoogleFonts.beVietnamPro(
                color: const Color(0xFFF4F4F5),
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ),

          // Status / Active Pill Container
          // Background: #121519, Border #2A2F36, Text 'Active' #22A575
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF121519),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF2A2F36),
                width: 1,
              ),
            ),
            child: Text(
              'Active',
              style: GoogleFonts.beVietnamPro(
                color: const Color(0xFF22A575),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildImpactSummaryCard() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 350, minHeight: 106),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF121519),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF2A2F36),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'ESTIMATED IMPACT',
            style: GoogleFonts.beVietnamPro(
              color: const Color(0xFF6E6E73),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  '-18% input tokens',
                  style: GoogleFonts.beVietnamPro(
                    color: const Color(0xFFF4F4F5),
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    height: 28 / 21,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                r'+ $0.40 / month',
                style: GoogleFonts.beVietnamPro(
                  color: const Color(0xFF22A575),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 18 / 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Confidence: High',
                style: GoogleFonts.beVietnamPro(
                  color: const Color(0xFF6E6E73),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  'Compared with prior 30 days',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.beVietnamPro(
                    color: const Color(0xFF6E6E73),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Evidence',
          style: GoogleFonts.beVietnamPro(
            color: const Color(0xFFF4F4F5),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 350, minHeight: 122),
          decoration: BoxDecoration(
            color: const Color(0xFF121519),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF2A2F36), width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Row 1 (Top: 18px, Left: 16px, Right: 16px)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Average input per request',
                        style: GoogleFonts.beVietnamPro(
                          color: const Color(0xFF6E6E73),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          height: 18 / 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '18.4k',
                      style: GoogleFonts.beVietnamPro(
                        color: const Color(0xFFF4F4F5),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 18 / 12,
                      ),
                    ),
                  ],
                ),
              ),

              // - Line (Figma spec: Width 318px, Height 0px, Left 16px, Border 1px #2A2F36)
              // Không dính sát viền ngoài mà cách mép đúng 16px mỗi bên!
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFF2A2F36),
                ),
              ),

              // Row 2
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Repeated context share',
                        style: GoogleFonts.beVietnamPro(
                          color: const Color(0xFF6E6E73),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          height: 18 / 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '42%',
                      style: GoogleFonts.beVietnamPro(
                        color: const Color(0xFFF4F4F5),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 18 / 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recommendation',
          style: GoogleFonts.beVietnamPro(
            color: const Color(0xFFF4F4F5),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Move stable instructions earlier, reduce duplicated context, and keep reusable context cacheable.',
          style: GoogleFonts.beVietnamPro(
            color: const Color(0xFF6E6E73),
            fontSize: 12,
            fontWeight: FontWeight.w400,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 12),
        // Privacy Note (Width: 350px, Height: 48px, Radius: 14px, Background: #121519)
        Container(
          width: 350,
          height: 48,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF121519),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            'Based on aggregate metadata only — no prompts or source code.',
            textAlign: TextAlign.center,
            style: GoogleFonts.beVietnamPro(
              color: const Color(0xFF6E6E73),
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    return Container(
      width: 350,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3D000000), // #000000 24%
            blurRadius: 6,
            offset: Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onMarkReviewed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF171717),
          foregroundColor: const Color(0xFF9C9FAB), // #9C9FAB chuẩn theo yêu cầu
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          'Mark as reviewed',
          style: GoogleFonts.beVietnamPro(
            color: const Color(0xFF9C9FAB),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      height: 68,
      decoration: const BoxDecoration(
        color: AppColors.navSurface,
        border: Border(
          top: BorderSide(color: AppColors.dockDivider, width: 1.0),
        ),
      ),
      child: Row(
        children: [
          _buildTabItem(
            name: 'Tokens',
            iconPath: 'assets/images/icons/tab_tokens.png',
            isActive: false,
          ),
          _buildTabItem(
            name: 'Analytics',
            iconPath: 'assets/images/icons/tab_analytics.png',
            isActive: false,
          ),
          _buildTabItem(
            name: 'Insights',
            iconPath: 'assets/images/icons/tab_insights.png',
            isActive: true,
          ),
          _buildTabItem(
            name: 'Settings',
            iconPath: 'assets/images/icons/tab_settings.png',
            isActive: false,
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required String name,
    required String iconPath,
    required bool isActive,
  }) {
    const activeColor = AppColors.navActive;
    const inactiveColor = AppColors.navInactive;

    return Expanded(
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Active rail at top edge (Figma spec: Width 56px, Height 4px, Radius 2px, Color #F2F3F5)
          if (isActive)
            Positioned(
              top: 0,
              child: Container(
                width: 56,
                height: 4,
                decoration: BoxDecoration(
                  color: activeColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          Positioned(
            top: 10,
            child: Image.asset(
              iconPath,
              width: 22,
              height: 22,
              color: isActive ? activeColor : inactiveColor,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            top: 39,
            left: 0,
            right: 0,
            height: 18,
            child: Center(
              child: Text(
                name,
                textAlign: TextAlign.center,
                style: GoogleFonts.beVietnamPro(
                  fontSize: isActive ? 11 : 10.5,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive ? activeColor : inactiveColor,
                  height: 16 / (isActive ? 11 : 10.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
