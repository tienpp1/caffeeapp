import 'dart:async';

import 'package:flutter/material.dart';

import 'cafe_theme.dart';
import 'category.dart';
import 'helper.dart';
import 'local_database.dart';
import 'member.dart';
import 'product.dart';
import 'session_helper.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _pageSize = 6;

  final _database = LocalDatabase.instance;
  final _searchController = TextEditingController();
  final _menuAnchor = GlobalKey();
  Timer? _searchTimer;
  int? _categoryId;
  String? _categoryName;
  int _page = 1;
  String _search = '';
  int _cartCount = 0;
  int _cartRequest = 0;
  late Future<PageResult<Product>> _products;
  late Future<List<Category>> _categories;

  @override
  void initState() {
    super.initState();
    _products = _query();
    _categories = _database.categories();
    SessionHelper.current.addListener(_refreshCart);
    _refreshCart();
  }

  @override
  void dispose() {
    SessionHelper.current.removeListener(_refreshCart);
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<PageResult<Product>> _query() => _database.products(
    categoryId: _categoryId,
    search: _search,
    page: _page,
    pageSize: _pageSize,
  );

  void _reload({bool categories = false, int? page}) {
    setState(() {
      if (page != null) _page = page;
      _products = _query();
      if (categories) _categories = _database.categories();
    });
  }

  Future<void> _refreshCart() async {
    final request = ++_cartRequest;
    final member = SessionHelper.current.value;
    var count = 0;
    if (member != null && !member.isAdmin) {
      try {
        count = await _database.cartCount(member.id);
      } on AppException {
        // The cart screen reports errors when opened.
      }
    }
    if (mounted && request == _cartRequest) setState(() => _cartCount = count);
  }

  void _searchFor(String text) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 230), () {
      _search = text.trim();
      _reload(page: 1);
    });
  }

  void _clearSearch() {
    _searchTimer?.cancel();
    _searchController.clear();
    _search = '';
    _reload(page: 1);
  }

  void _selectCategory(Category? category) {
    _categoryId = category?.id;
    _categoryName = category?.name;
    _reload(page: 1);
  }

  void _scrollToMenu() {
    final anchor = _menuAnchor.currentContext;
    if (anchor == null) return;
    Scrollable.ensureVisible(
      anchor,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      alignment: .03,
    );
  }

  Future<void> _open(String route, {Object? arguments}) async {
    await Navigator.pushNamed(context, route, arguments: arguments);
    if (!mounted) return;
    if (route.startsWith('/admin/')) {
      _categoryId = null;
      _categoryName = null;
      _reload(categories: true, page: 1);
    } else if (route == '/cart' || route == '/details') {
      _reload();
    }
    await _refreshCart();
  }

  Future<void> _logout() async {
    try {
      await SessionHelper.delete();
      if (mounted) showMessage(context, 'Đã đăng xuất.');
    } catch (error) {
      if (mounted) showMessage(context, errorMessage(error));
    }
  }

  List<({String label, IconData icon, String route})> _links(Member? member) {
    if (member == null) {
      return [
        (label: 'Đăng nhập', icon: Icons.login, route: '/login'),
        (label: 'Đăng ký', icon: Icons.person_add_outlined, route: '/register'),
      ];
    }
    return [
      (label: 'Tài khoản', icon: Icons.person_outline, route: '/profile'),
      if (member.isAdmin) ...[
        (
          label: 'Quản lý danh mục',
          icon: Icons.category_outlined,
          route: '/admin/categories',
        ),
        (
          label: 'Quản lý món',
          icon: Icons.local_cafe_outlined,
          route: '/admin/products',
        ),
        (
          label: 'Quản lý đơn',
          icon: Icons.receipt_long_outlined,
          route: '/admin/orders',
        ),
        (
          label: 'Thành viên và vai trò',
          icon: Icons.manage_accounts_outlined,
          route: '/admin/members',
        ),
      ] else ...[
        (label: 'Giỏ món', icon: Icons.shopping_bag_outlined, route: '/cart'),
        (
          label: 'Đơn của tôi',
          icon: Icons.receipt_long_outlined,
          route: '/orders',
        ),
      ],
    ];
  }

  Widget _drawer(Member? member) {
    final theme = Theme.of(context);
    return NavigationDrawer(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(26, 25, 22, 19),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Wordmark(title: widget.title),
              if (member != null) ...[
                const SizedBox(height: 16),
                Text(
                  member.email,
                  style: theme.textTheme.bodyMedium?.copyWith(color: cafeMuted),
                ),
              ],
            ],
          ),
        ),
        const Divider(indent: 24, endIndent: 24),
        for (final link in _links(member))
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 26),
            leading: Icon(link.icon),
            title: Text(link.label),
            onTap: () {
              Navigator.pop(context);
              _open(link.route);
            },
          ),
        if (member != null)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 26),
            leading: const Icon(Icons.logout),
            title: const Text('Đăng xuất'),
            onTap: () {
              Navigator.pop(context);
              _logout();
            },
          ),
      ],
    );
  }

  Widget _header(Member? member, double side, bool desktop, double height) {
    final theme = Theme.of(context);
    return Material(
      color: cafeSurface,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: cafeLine)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: desktop ? side : 10),
            child: SizedBox(
              height: height,
              child: Row(
                children: [
                  if (!desktop)
                    Builder(
                      builder: (context) => IconButton(
                        tooltip: 'Mở trình đơn',
                        onPressed: Scaffold.of(context).openDrawer,
                        icon: const Icon(Icons.menu, size: 22),
                      ),
                    ),
                  Expanded(
                    child: _Wordmark(title: widget.title, compact: !desktop),
                  ),
                  if (desktop) ...[
                    TextButton(
                      onPressed: _scrollToMenu,
                      child: const Text('Thực đơn'),
                    ),
                    if (member != null && !member.isAdmin)
                      TextButton(
                        onPressed: () => _open('/orders'),
                        child: const Text('Đơn của tôi'),
                      ),
                    if (member?.isAdmin == true)
                      PopupMenuButton<String>(
                        tooltip: 'Mở chức năng quản trị',
                        onSelected: _open,
                        itemBuilder: (_) => [
                          for (final link in _links(
                            member,
                          ).where((link) => link.route.startsWith('/admin/')))
                            PopupMenuItem(
                              value: link.route,
                              child: Text(link.label),
                            ),
                        ],
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Quản trị',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              SizedBox(width: 5),
                              Icon(Icons.expand_more, size: 17),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                  ],
                  if (member == null)
                    FilledButton.tonal(
                      onPressed: () => _open('/login'),
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: desktop ? 18 : 13,
                        ),
                        minimumSize: const Size(0, 42),
                      ),
                      child: const Text('Đăng nhập'),
                    )
                  else ...[
                    if (!member.isAdmin)
                      IconButton.outlined(
                        tooltip: 'Giỏ món',
                        onPressed: () => _open('/cart'),
                        icon: Badge(
                          backgroundColor: theme.colorScheme.secondary,
                          isLabelVisible: _cartCount > 0,
                          label: Text('$_cartCount'),
                          child: const Icon(
                            Icons.shopping_bag_outlined,
                            size: 21,
                          ),
                        ),
                      ),
                    if (desktop || member.isAdmin) ...[
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        tooltip: 'Tài khoản',
                        onPressed: () => _open('/profile'),
                        icon: const Icon(Icons.person_outline, size: 21),
                      ),
                    ],
                  ],
                  if (!desktop) const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final member = SessionHelper.current.value;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
        final desktop = width >= 860 && textScale < 1.5;
        final headerHeight = desktop
            ? 74.0
            : 61 + (textScale - 1).clamp(0.0, 1.0) * 20;
        final columns = width >= 740
            ? 3
            : (width >= 315 && textScale < 1.6 ? 2 : 1);
        final side = width > 1312
            ? (width - 1248) / 2
            : (desktop ? 32.0 : 16.0);
        final gap = desktop ? 20.0 : 12.0;
        final tileWidth = (width - side * 2 - gap * (columns - 1)) / columns;
        final tileHeight =
            (tileWidth * .62).clamp(118.0, 221.0) +
            (desktop ? 83 : 96) * textScale;
        return Scaffold(
          drawer: _drawer(member),
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(headerHeight),
            child: _header(member, side, desktop, headerHeight),
          ),
          body: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  side,
                  desktop ? 28 : 14,
                  side,
                  desktop ? 33 : 23,
                ),
                sliver: SliverToBoxAdapter(
                  child: _MenuHero(
                    compact: !desktop,
                    onOpenMenu: _scrollToMenu,
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: side),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    key: _menuAnchor,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thực đơn',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 13),
                      _filters(desktop),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 17),
                    ],
                  ),
                ),
              ),
              _productSlivers(side, columns, gap, tileHeight),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(side, 22, side, 22),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const Divider(),
                      const SizedBox(height: 13),
                      _Wordmark(title: widget.title, compact: true),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _filters(bool desktop) {
    final search = TextField(
      controller: _searchController,
      onChanged: _searchFor,
      onSubmitted: _searchFor,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        labelText: 'Tìm món',
        hintText: 'Nhập tên món hoặc nguyên liệu',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: ValueListenableBuilder(
          valueListenable: _searchController,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Xóa từ khóa',
                  onPressed: _clearSearch,
                  icon: const Icon(Icons.close),
                ),
        ),
      ),
    );
    final categories = FutureBuilder<List<Category>>(
      future: _categories,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return TextButton.icon(
            onPressed: () => _reload(categories: true),
            icon: const Icon(Icons.refresh),
            label: const Text('Tải lại danh mục'),
          );
        }
        final chips = [
          _categoryChip(),
          for (final category in snapshot.data ?? const <Category>[])
            _categoryChip(category: category),
        ];
        return Wrap(runSpacing: 3, children: chips);
      },
    );
    if (desktop) {
      return Row(
        children: [
          Expanded(child: categories),
          const SizedBox(width: 18),
          SizedBox(width: 315, child: search),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [search, const SizedBox(height: 6), categories],
    );
  }

  Widget _categoryChip({Category? category}) {
    final id = category?.id;
    final selected = _categoryId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        showCheckmark: false,
        visualDensity: const VisualDensity(horizontal: 0, vertical: 0),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        avatar: category == null
            ? const Icon(Icons.grid_view_rounded, size: 17)
            : (category.icon.isEmpty && category.imageId == null)
            ? null
            : ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: ProductImage(
                  asset: category.icon,
                  imageId: category.imageId,
                  fit: BoxFit.cover,
                  width: 20,
                  height: 20,
                ),
              ),
        label: Text(category?.name ?? 'Tất cả món'),
        labelStyle: TextStyle(
          color: selected ? Colors.white : cafeInk,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        iconTheme: IconThemeData(color: selected ? Colors.white : cafeForest),
        selectedColor: cafeForest,
        side: BorderSide(color: selected ? cafeForest : cafeLine),
        selected: selected,
        onSelected: (_) => _selectCategory(category),
      ),
    );
  }

  Widget _productSlivers(
    double side,
    int columns,
    double gap,
    double tileHeight,
  ) {
    return FutureBuilder<PageResult<Product>>(
      future: _products,
      builder: (context, snapshot) {
        if (snapshot.hasError &&
            snapshot.connectionState == ConnectionState.done) {
          return SliverToBoxAdapter(
            child: LoadError(error: snapshot.error, retry: _reload),
          );
        }
        final result = snapshot.data;
        final title = _search.isNotEmpty
            ? 'Kết quả tìm kiếm'
            : _categoryName ?? 'Món mới nhất';
        final progress = snapshot.connectionState != ConnectionState.done;
        return SliverMainAxisGroup(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(side, 0, side, 15),
              sliver: SliverToBoxAdapter(
                child: Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (result != null && !progress)
                      Text(
                        '${result.total} món',
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(color: cafeMuted),
                      ),
                  ],
                ),
              ),
            ),
            if (progress)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (result == null || result.items.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(side, 20, side, 35),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.search_off,
                          color: cafeMuted,
                          size: 34,
                        ),
                        const SizedBox(height: 10),
                        const Text('Không tìm thấy món phù hợp.'),
                        if (_search.isNotEmpty)
                          TextButton(
                            onPressed: _clearSearch,
                            child: const Text('Xóa từ khóa'),
                          ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: side),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: gap,
                    mainAxisSpacing: gap,
                    mainAxisExtent: tileHeight,
                  ),
                  itemCount: result.items.length,
                  itemBuilder: (_, index) {
                    final product = result.items[index];
                    return ProductCard(
                      key: ValueKey(product.id),
                      product: product,
                      onTap: () => _open('/details', arguments: product.id),
                    );
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: PagingControls(
                    page: _page,
                    total: result.total,
                    pageSize: _pageSize,
                    onChanged: (page) {
                      _reload(page: page);
                      _scrollToMenu();
                    },
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.title, this.compact = false});

  final String title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 32.0 : 41.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: cafeForest,
            borderRadius: BorderRadius.circular(compact ? 11 : 13),
          ),
          child: Icon(
            Icons.coffee_outlined,
            color: cafeSurface,
            size: compact ? 17 : 23,
          ),
        ),
        SizedBox(width: compact ? 7 : 11),
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: compact ? 20 : 28,
              letterSpacing: -.55,
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuHero extends StatelessWidget {
  const _MenuHero({required this.compact, required this.onOpenMenu});

  final bool compact;
  final VoidCallback onOpenMenu;

  @override
  Widget build(BuildContext context) {
    const dark = Color(0xFF2D2018);
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final mobilePhoto = compact && width < 530;
        final copy = Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 21 : 50,
            compact ? 24 : 42,
            18,
            compact ? 25 : 43,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Thực đơn\ntại bàn',
                style:
                    (compact
                            ? theme.textTheme.headlineLarge
                            : theme.textTheme.displayLarge)
                        ?.copyWith(
                          color: cafeSurface,
                          height: 1.04,
                          fontSize: compact && width < 350 ? 31 : null,
                        ),
              ),
              const SizedBox(height: 14),
              Text(
                'Chọn món, nhập số bàn và gửi đơn cho quầy.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFF0E0CF),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 19),
              FilledButton.icon(
                onPressed: onOpenMenu,
                icon: const Icon(Icons.south_rounded, size: 17),
                label: const Text('Xem thực đơn'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFEEE4D2),
                  foregroundColor: cafeInk,
                  padding: EdgeInsets.symmetric(horizontal: compact ? 13 : 17),
                  minimumSize: const Size(0, 44),
                ),
              ),
            ],
          ),
        );

        return ClipRRect(
          borderRadius: BorderRadius.circular(compact ? 21 : 27),
          child: DecoratedBox(
            decoration: const BoxDecoration(color: dark),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  width: width * (mobilePhoto ? .59 : .56),
                  child: Image.asset(
                    'assets/branding/menu-hero.webp',
                    alignment: mobilePhoto
                        ? const Alignment(.47, .08)
                        : const Alignment(.23, -.08),
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => Image.asset(
                      'assets/products/ca-phe-muoi.jpg',
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  width: width * (mobilePhoto ? .59 : .56),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [dark, Color(0x662D2018), Color(0x002D2018)],
                        stops: [0, .28, .67],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: width * (mobilePhoto ? .70 : .48), child: copy),
              ],
            ),
          ),
        );
      },
    );
  }
}
