# CCodeAnalyzer


## Function Spec

### FlattenFiles

Due to if we include too many header files in different folder, will cause the clang process slow. The optimization solution is we use a flatten method to gather all wanted files into a temp folder. This will help the clang performance.

In addition, due to the header files may be too many, 