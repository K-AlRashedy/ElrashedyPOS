class PosBranch {
  const PosBranch({required this.id, required this.name});
  final int id;
  final String name;

  factory PosBranch.fromJson(Map<String, dynamic> json) =>
      PosBranch(id: (json['id'] as num).toInt(), name: json['name'] as String);
}

class ProductCategory {
  const ProductCategory({required this.id, required this.name});
  final String id;
  final String name;

  factory ProductCategory.fromJson(Map<String, dynamic> json) =>
      ProductCategory(id: json['id'].toString(), name: json['name'] as String);
}

class PosProduct {
  const PosProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.categoryId,
    required this.category,
    required this.categoryIds,
    required this.categories,
    this.image,
  });

  final int id;
  final String name;
  final String price;
  final String categoryId;
  final String category;
  final List<String> categoryIds;
  final List<ProductCategory> categories;
  final String? image;

  factory PosProduct.fromJson(Map<String, dynamic> json) {
    final categories = (json['categories'] as List<dynamic>? ?? [])
        .map((item) => ProductCategory.fromJson(item as Map<String, dynamic>))
        .toList();
    final categoryIds = (json['category_ids'] as List<dynamic>? ?? [])
        .map((item) => item.toString())
        .toList();
    return PosProduct(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      price: json['price'].toString(),
      categoryId: json['category_id']?.toString() ?? '',
      category: json['category'] as String? ?? '',
      categoryIds: categoryIds.isNotEmpty
          ? categoryIds
          : (categories.isNotEmpty ? categories.map((c) => c.id).toList() : [json['category_id']?.toString() ?? '']),
      categories: categories.isNotEmpty
          ? categories
          : [ProductCategory(id: json['category_id']?.toString() ?? 'other', name: json['category'] as String? ?? 'أصناف أخرى')],
      image: json['image'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'category_id': categoryId,
        'category': category,
        'category_ids': categoryIds,
        'categories': categories.map((c) => {'id': c.id, 'name': c.name}).toList(),
        'image': image,
      };

  bool get isMenuSection => categoryIds.any((id) => id.startsWith('section-'));
}

class PosEmployee {
  const PosEmployee({required this.id, required this.name, required this.branchId});
  final int id;
  final String name;
  final int branchId;

  factory PosEmployee.fromJson(Map<String, dynamic> json) => PosEmployee(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        branchId: (json['branch_id'] as num).toInt(),
      );
}

class PosSupplier {
  const PosSupplier({required this.id, required this.name});
  final int id;
  final String name;

  factory PosSupplier.fromJson(Map<String, dynamic> json) =>
      PosSupplier(id: (json['id'] as num).toInt(), name: json['name'] as String);
}

class ExpenseAccount {
  const ExpenseAccount({required this.id, required this.name, this.parentId});
  final int id;
  final String name;
  final int? parentId;

  factory ExpenseAccount.fromJson(Map<String, dynamic> json) => ExpenseAccount(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        parentId: json['parent_id'] == null ? null : (json['parent_id'] as num).toInt(),
      );
}

class NamedOption {
  const NamedOption({required this.value, required this.label});
  final String value;
  final String label;

  factory NamedOption.fromJson(Map<String, dynamic> json) =>
      NamedOption(value: json['value'] as String, label: json['label'] as String);
}

class PosUser {
  const PosUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.isSuperuser,
    required this.permissions,
    this.employeeId,
    this.branchName,
  });

  final int id;
  final String username;
  final String displayName;
  final bool isSuperuser;
  final Map<String, bool> permissions;
  final int? employeeId;
  final String? branchName;

  factory PosUser.fromJson(Map<String, dynamic> json) => PosUser(
        id: (json['id'] as num).toInt(),
        username: json['username'] as String,
        displayName: json['display_name'] as String? ?? json['username'] as String,
        isSuperuser: json['is_superuser'] as bool? ?? false,
        employeeId: json['employee_id'] == null ? null : (json['employee_id'] as num).toInt(),
        branchName: json['branch_name'] as String?,
        permissions: (json['permissions'] as Map<String, dynamic>? ?? {})
            .map((key, value) => MapEntry(key, value == true)),
      );
}

class Bootstrap {
  const Bootstrap({
    required this.user,
    required this.branches,
    required this.products,
    required this.mainAccounts,
    required this.subAccounts,
    required this.employees,
    required this.suppliers,
    required this.shifts,
    required this.orderTypes,
    required this.paymentMethods,
    required this.operationalDate,
  });

  final PosUser user;
  final List<PosBranch> branches;
  final List<PosProduct> products;
  final List<ExpenseAccount> mainAccounts;
  final List<ExpenseAccount> subAccounts;
  final List<PosEmployee> employees;
  final List<PosSupplier> suppliers;
  final List<NamedOption> shifts;
  final List<NamedOption> orderTypes;
  final List<NamedOption> paymentMethods;
  final String operationalDate;

  factory Bootstrap.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) =>
        (json[key] as List<dynamic>? ?? []).map((item) => parse(item as Map<String, dynamic>)).toList();
    final accounts = json['expense_accounts'] as Map<String, dynamic>? ?? {};
    return Bootstrap(
      user: PosUser.fromJson(json['user'] as Map<String, dynamic>),
      branches: list('branches', PosBranch.fromJson),
      products: list('products', PosProduct.fromJson),
      mainAccounts: (accounts['main'] as List<dynamic>? ?? [])
          .map((item) => ExpenseAccount.fromJson(item as Map<String, dynamic>))
          .toList(),
      subAccounts: (accounts['sub'] as List<dynamic>? ?? [])
          .map((item) => ExpenseAccount.fromJson(item as Map<String, dynamic>))
          .toList(),
      employees: list('employees', PosEmployee.fromJson),
      suppliers: list('suppliers', PosSupplier.fromJson),
      shifts: list('shifts', NamedOption.fromJson),
      orderTypes: list('order_types', NamedOption.fromJson),
      paymentMethods: list('payment_methods', NamedOption.fromJson),
      operationalDate: json['operational_date'] as String? ?? '',
    );
  }
}