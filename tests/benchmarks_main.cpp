#include "numerical/matrix_ops.hpp"
#include <iostream>
#include <chrono>

int main() {
    constexpr size_t N = 1024;
    std::vector<std::vector<double>> A(N, std::vector<double>(N, 2.0));
    std::vector<std::vector<double>> B(N, std::vector<double>(N, 1.0));
    auto start = std::chrono::steady_clock::now();
    auto C = multiply(A, B);
    auto end = std::chrono::steady_clock::now();
    std::chrono::duration<double> elapsed = end - start;
    std::cout << "Matrix multiplication took " << elapsed.count() << " seconds\n";
    std::cout << "Result sample: " << C[0][0] << std::endl;
    return 0;
}
