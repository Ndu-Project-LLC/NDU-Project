/// ShopFlow reference implementation in the FlutterFlow AI DSL.
///
/// This file is the canonical ShopFlow reference app for compiler/runtime
/// smoke coverage and workspace examples.
///
/// Equivalent to the 12 gold standard task files in a materially smaller DSL
/// surface than the current ~1,300-line gold standard.
library;

import 'dart:io';

import 'package:flutterflow_ai/flutterflow_ai.dart';

Future<void> main(List<String> args) async {
  final options = _parseCliOptions(args);
  await flutterFlowAI(
    buildShopFlow,
    apiKey: options.apiKey,
    baseUrl: options.baseUrl,
    projectName: options.projectName,
    projectId: options.projectId,
    findOrCreate: options.findOrCreate,
    dryRun: options.dryRun,
    commitMessage: options.commitMessage,
  );
}

final class _CliOptions {
  const _CliOptions({
    this.apiKey,
    this.baseUrl,
    this.projectName,
    this.projectId,
    this.findOrCreate = false,
    this.dryRun = false,
    this.commitMessage,
  });

  final String? apiKey;
  final String? baseUrl;
  final String? projectName;
  final String? projectId;
  final bool findOrCreate;
  final bool dryRun;
  final String? commitMessage;
}

_CliOptions _parseCliOptions(List<String> args) {
  String? apiKey;
  String? baseUrl;
  String? projectName;
  String? projectId;
  String? commitMessage;
  var findOrCreate = false;
  var dryRun = false;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    switch (arg) {
      case '--help':
      case '-h':
        _printUsage();
        exit(0);
      case '--api-key':
        apiKey = _requireValue(args, ++i, '--api-key');
      case '--base-url':
        baseUrl = _requireValue(args, ++i, '--base-url');
      case '--project-name':
        projectName = _requireValue(args, ++i, '--project-name');
      case '--project-id':
        projectId = _requireValue(args, ++i, '--project-id');
      case '--commit-message':
        commitMessage = _requireValue(args, ++i, '--commit-message');
      case '--find-or-create':
        findOrCreate = true;
      case '--dry-run':
        dryRun = true;
      default:
        stderr.writeln('Unknown option: $arg');
        _printUsage();
        exit(64);
    }
  }

  return _CliOptions(
    apiKey: apiKey,
    baseUrl: baseUrl,
    projectName: projectName,
    projectId: projectId,
    findOrCreate: findOrCreate,
    dryRun: dryRun,
    commitMessage: commitMessage,
  );
}

String _requireValue(List<String> args, int index, String flag) {
  if (index >= args.length) {
    stderr.writeln('Missing value for $flag.');
    _printUsage();
    exit(64);
  }
  return args[index];
}

void _printUsage() {
  stdout.writeln('''
Run the ShopFlow DSL and push the compiled project to FlutterFlow.

Usage:
  dart run specs/dsl/shopflow_dsl.dart [options]

Options:
  --api-key <key>           FlutterFlow API key. Defaults to FF_API_KEY.
  --base-url <url>          Override the FlutterFlow API base URL.
  --project-name <name>     Create a new project with this name.
  --project-id <id>         Push into an existing project by ID.
  --find-or-create          Find by project name before creating.
  --commit-message <text>   Commit message for the push.
  --dry-run                 Compile and validate without pushing.
  --help, -h                Show this help.
''');
}

void buildShopFlow(App app) {
  // ====================== DATA MODEL ======================

  final productCategory = app.enum_('ProductCategory', [
    'electronics',
    'clothing',
    'home',
    'sports',
    'books',
  ]);

  final product = app.struct('Product', {
    'name': string,
    'description': string,
    'price': double_,
    'category': enum_(productCategory),
    'inStock': bool_,
    'imageUrl': string,
  });

  final cartItem = app.struct('CartItem', {
    'productName': string,
    'quantity': int_,
    'unitPrice': double_,
  });

  // ====================== APP STATE =======================

  app.state('cartItems', listOf(cartItem), persisted: true);
  app.state('isCartOpen', bool_);

  app.constant('storeName', 'ShopFlow');
  app.constant('maxCartItems', 50);
  app.constant('supportEmail', 'help@shopflow.com');

  // ======================== API ===========================

  final listProducts = Endpoint.get(
    'ListProducts',
    '/products?q=[q]',
    variables: {'q': string},
    response: listOf(product),
  );
  final getProduct = Endpoint.get(
    'GetProduct',
    '/products/[id]',
    variables: {'id': string},
    response: product,
  );
  final createProduct = Endpoint.post(
    'CreateProduct',
    '/products',
    body: {'name': '<name>', 'price': '<price>', 'category': '<category>'},
    variables: {'name': string, 'price': double_, 'category': string},
    response: product,
  );

  app.apiGroup(
    'ProductAPI',
    baseUrl: 'http://localhost:8085/v1',
    headers: {'Content-Type': 'application/json'},
    endpoints: [listProducts, getProduct, createProduct],
  );

  // ===================== COMPONENTS =======================

  final dynamic productCard = app.component(
    'ProductCard',
    params: {
      'productName': string,
      'price': double_,
      'category': enum_(productCategory),
      'inStock': bool_,
      'onTapAction': action,
    },
    body: Container(
      onTap: ParamAction('onTapAction'),
      color: Colors.secondaryBackground,
      padding: 16,
      borderRadius: 12,
      shadow: Shadow(blur: 4, dy: 2, color: Colors.hex(0x1A000000)),
      child: Column(
        crossAxis: CrossAxis.start,
        spacing: 8,
        children: [
          Text(Param('productName'), style: Styles.titleMedium),
          Row(
            mainAxis: MainAxis.spaceBetween,
            children: [
              Text(Param('price'), style: Styles.titleSmall),
              Row(
                spacing: 4,
                children: [
                  Icon(
                    'check_circle',
                    size: 18,
                    color: Colors.success,
                    visible: Param('inStock'),
                  ),
                  Icon(
                    'cancel',
                    size: 18,
                    color: Colors.error,
                    visible: Not(Param('inStock')),
                  ),
                ],
              ),
            ],
          ),
          Text(
            Param('category'),
            style: Styles.labelSmall,
            color: Colors.secondaryText,
          ),
        ],
      ),
    ),
  );

  final dynamic cartItemCard = app.component(
    'CartItemCard',
    params: {'productName': string, 'quantity': int_, 'unitPrice': double_},
    body: Container(
      color: Colors.secondaryBackground,
      padding: 16,
      borderRadius: 8,
      child: Row(
        mainAxis: MainAxis.spaceBetween,
        children: [
          Expanded(Text(Param('productName'), style: Styles.titleSmall)),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            borderRadius: 4,
            color: Colors.primaryBackground,
            child: Text(Param('quantity'), style: Styles.bodyMedium),
          ),
          Text(Param('unitPrice'), style: Styles.titleSmall),
          IconButton('delete_outline', size: 20, color: Colors.error),
        ],
      ),
    ),
  );

  // ======================= PAGES =========================

  app.page(
    'ProductListPage',
    route: '/products',
    isInitial: true,
    state: {
      'products': listOf(product),
      'isLoading': bool_.withDefault(true),
      'searchQuery': string,
    },
    onLoad: [
      ApiCall(
        listProducts,
        onSuccess:
            (res) => [SetState('products', res), SetState('isLoading', false)],
        onFailure: [
          SetState('isLoading', false),
          Snackbar('Failed to load products'),
        ],
      ),
    ],
    body: Scaffold(
      appBar: AppBar(title: 'ShopFlow'),
      body: Container(
        color: Colors.primaryBackground,
        padding: 16,
        child: Column(
          spacing: 8,
          children: [
            TextField(
              hint: 'Search products...',
              prefixIcon: 'search',
              onChanged: SetState('searchQuery', TextValue()),
              onSubmitted: ApiCall(
                listProducts,
                params: {'q': State('searchQuery')},
                onSuccess: (res) => [SetState('products', res)],
                onFailure: [Snackbar('Search failed')],
              ),
            ),
            Button(
              'Refresh',
              variant: ButtonVariant.outlined,
              icon: 'refresh',
              width: double.infinity,
              height: 40,
              onTap: [
                ApiCall(
                  listProducts,
                  onSuccess:
                      (res) => [
                        SetState('products', res),
                        Snackbar('Products refreshed'),
                      ],
                  onFailure: [Snackbar('Failed to refresh products')],
                ),
              ],
            ),
            ProgressBar.circular(
              size: 40,
              thickness: 4,
              visible: State('isLoading'),
            ),
            Expanded(
              ListView(
                source: State('products'),
                spacing: 8,
                visible: Not(State('isLoading')),
                itemBuilder:
                    (item) => productCard(
                      productName: item['name'],
                      price: item['price'],
                      category: item['category'],
                      inStock: item['inStock'],
                      onTapAction: Navigate(
                        'ProductDetailPage',
                        params: {'productId': item['name']},
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  app.page(
    'ProductDetailPage',
    route: '/product-detail',
    params: {'productId': string},
    state: {
      'product': product,
      'isLoading': bool_.withDefault(true),
      'quantity': int_.withDefault(1),
    },
    onLoad: [
      ApiCall(
        getProduct,
        params: {'id': PageParam('productId')},
        onSuccess:
            (res) => [SetState('product', res), SetState('isLoading', false)],
        onFailure: [
          SetState('isLoading', false),
          Snackbar('Product not found'),
        ],
      ),
    ],
    body: Scaffold(
      appBar: AppBar(title: 'Product Details'),
      body: Container(
        color: Colors.primaryBackground,
        padding: 24,
        child: Column(
          crossAxis: CrossAxis.start,
          spacing: 16,
          children: [
            ProgressBar.circular(
              size: 40,
              thickness: 4,
              visible: State('isLoading'),
            ),
            Column(
              crossAxis: CrossAxis.start,
              spacing: 16,
              visible: Not(State('isLoading')),
              children: [
                Text(State('product')['name'], style: Styles.headlineMedium),
                Text(State('product')['description'], style: Styles.bodyMedium),
                Text(State('product')['price'], style: Styles.titleLarge),
                Row(
                  spacing: 8,
                  children: [
                    Text(
                      State('product')['category'],
                      style: Styles.labelMedium,
                    ),
                    Icon(
                      'check_circle',
                      size: 22,
                      color: Colors.success,
                      visible: State('product')['inStock'],
                    ),
                    Icon(
                      'cancel',
                      size: 22,
                      color: Colors.error,
                      visible: Not(State('product')['inStock']),
                    ),
                  ],
                ),
                Divider(),
                Row(
                  mainAxis: MainAxis.center,
                  spacing: 16,
                  children: [
                    IconButton(
                      'remove',
                      size: 20,
                      fillColor: Colors.secondaryBackground,
                      borderRadius: 8,
                      onTap: [SetState.increment('quantity', -1)],
                    ),
                    Text(State('quantity'), style: Styles.titleMedium),
                    IconButton(
                      'add',
                      size: 20,
                      fillColor: Colors.secondaryBackground,
                      borderRadius: 8,
                      onTap: [SetState.increment('quantity', 1)],
                    ),
                  ],
                ),
                Button(
                  'Add to Cart',
                  icon: 'shopping_cart',
                  width: double.infinity,
                  height: 48,
                  onTap: [
                    UpdateAppState.addToList(
                      'cartItems',
                      Struct(cartItem, {
                        'productName': State('product')['name'],
                        'quantity': State('quantity'),
                        'unitPrice': State('product')['price'],
                      }),
                    ),
                    Snackbar('Added to cart!'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  app.page(
    'CartPage',
    route: '/cart',
    state: {
      'cartItems': listOf(cartItem),
      'isCartEmpty': bool_.withDefault(true),
    },
    onLoad: [
      SetState('cartItems', AppState('cartItems')),
      SetState('isCartEmpty', false),
    ],
    body: Scaffold(
      appBar: AppBar(title: 'Shopping Cart'),
      body: Container(
        color: Colors.primaryBackground,
        padding: 16,
        child: Column(
          spacing: 16,
          children: [
            Row(
              mainAxis: MainAxis.spaceBetween,
              children: [
                Text('Cart Items', style: Styles.headlineSmall),
                Icon('shopping_bag', size: 24, color: Colors.primary),
              ],
            ),
            Column(
              mainAxis: MainAxis.center,
              spacing: 8,
              visible: State('isCartEmpty'),
              children: [
                Icon(
                  'shopping_cart_outlined',
                  size: 64,
                  color: Colors.secondaryText,
                ),
                Text('Your cart is empty', style: Styles.bodyLarge),
                Text(
                  'Add items from the product catalog',
                  style: Styles.bodySmall,
                  color: Colors.secondaryText,
                ),
              ],
            ),
            Expanded(
              ListView(
                source: State('cartItems'),
                spacing: 8,
                visible: Not(State('isCartEmpty')),
                itemBuilder:
                    (item) => cartItemCard(
                      productName: item['productName'],
                      quantity: item['quantity'],
                      unitPrice: item['unitPrice'],
                    ),
              ),
            ),
            Divider(),
            Text('Total: calculated at checkout', style: Styles.titleMedium),
            Button(
              'Clear Cart',
              variant: ButtonVariant.outlined,
              icon: 'delete_outline',
              width: double.infinity,
              height: 40,
              onTap: [
                ClearAppState('cartItems'),
                SetState.clear('cartItems'),
                SetState('isCartEmpty', true),
                Snackbar('Cart cleared'),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  app.page(
    'AddProductPage',
    route: '/add-product',
    state: {
      'productName': string,
      'productPrice': double_.withDefault(9.99),
      'productCategory': string.withDefault('electronics'),
    },
    body: Scaffold(
      appBar: AppBar(title: 'Add Product'),
      body: Container(
        color: Colors.primaryBackground,
        padding: 24,
        child: Column(
          crossAxis: CrossAxis.start,
          spacing: 16,
          children: [
            Text('New Product', style: Styles.headlineMedium),
            TextField(
              label: 'Product Name',
              hint: 'Enter product name',
              onChanged: SetState('productName', TextValue()),
            ),
            TextField(label: 'Description', hint: 'Enter product description'),
            TextField(
              label: 'Price',
              hint: '0.00',
              keyboard: Keyboard.number,
              onChanged: SetState('productPrice', TextValue().asDouble()),
            ),
            TextField(
              label: 'Category',
              hint: 'e.g. electronics',
              onChanged: SetState('productCategory', TextValue()),
            ),
            Toggle(label: 'In Stock', value: true),
            Button(
              'Create Product',
              icon: 'add',
              width: double.infinity,
              height: 48,
              onTap: [
                ApiCall(
                  createProduct,
                  params: {
                    'name': State('productName'),
                    'price': State('productPrice'),
                    'category': State('productCategory'),
                  },
                  onSuccess:
                      (res) => [
                        Snackbar('Product created!'),
                        Navigate('ProductListPage'),
                      ],
                  onFailure: [Snackbar('Failed to create product')],
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
