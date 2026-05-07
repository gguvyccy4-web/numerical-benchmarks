#include "numerical/matrix_ops.hpp"
#include <iostream>
#include <chrono>

int main() {
    constexpr size_t N = 1024;
    std::vector<std::vector<double>> A(N, std::vector<double>(N, 2.0));
    std::vector<std::vector<double>> B(N, std::vector<double>(N, 1.0));

    std::cout << "Running extended benchmark (100 iterations)...\n";
    auto totalStart = std::chrono::steady_clock::now();

    for (int iter = 1; iter <= 100; ++iter) {
        auto start = std::chrono::steady_clock::now();
        auto C = multiply(A, B);
        auto end = std::chrono::steady_clock::now();
        std::chrono::duration<double> elapsed = end - start;
        std::cout << "Iteration " << iter << "/100: " 
                  << elapsed.count() << " seconds, result[0][0]=" << C[0][0] << "\n";
    }

    auto totalEnd = std::chrono::steady_clock::now();
    std::chrono::duration<double> total = totalEnd - totalStart;
    std::cout << "Total benchmark time: " << total.count() << " seconds\n";
    return 0;
}
