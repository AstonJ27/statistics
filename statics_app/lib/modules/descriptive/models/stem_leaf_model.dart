class StemLeafItem {
  final int stem;
  final List<int> leaves;
  
  StemLeafItem({required this.stem, required this.leaves});
  
  factory StemLeafItem.fromJson(Map<String, dynamic> j) {
    return StemLeafItem(
      stem: (j['stem'] as num).toInt(), 
      leaves: (j['leaves'] as List).map((e) => (e as num).toInt()).toList()
    );
  }
}