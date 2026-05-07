#include "numerical/matrix_ops.hpp"

std::vector<std::vector<double>> multiply(
    const std::vector<std::vector<double>>& A,
    const std::vector<std::vector<double>>& B
) {
    size_t n = A.size();
    size_t m = B[0].size();
    size_t p = B.size();
    std::vector<std::vector<double>> C(n, std::vector<double>(m, 0.0));
    for (size_t i = 0; i < n; ++i)
        for (size_t j = 0; j < m; ++j)
            for (size_t k = 0; k < p; ++k)
                C[i][j] += A[i][k] * B[k][j];
    return C;
}
