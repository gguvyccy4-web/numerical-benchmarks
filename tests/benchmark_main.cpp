#include "numerical/matrix_ops.hpp"
#include <iostream>
#include <chrono>

int main() {
    constexpr size_t N = 1024;
    std::vector<std::vector<double>> A(N, std::vector<double>(N, 2.0));
    std::vector<std::vector<double>> B(N, std::vector<double>(N, 1.0));

    auto totalStart = std::chrono::steady_clock::now();
    auto targetDuration = std::chrono::minutes(55);

    int iter = 0;
    while (std::chrono::steady_clock::now() - totalStart < targetDuration) {
        ++iter;
        auto start = std::chrono::steady_clock::now();
        auto C = multiply(A, B);
        auto end = std::chrono::steady_clock::now();
        std::chrono::duration<double> elapsed = end - start;
        if (iter % 10 == 0) {
            std::cout << "Iteration " << iter << ": " 
                      << elapsed.count() << " sec, result[0][0]=" << C[0][0] << "\n";
        }
    }

    auto totalTime = std::chrono::steady_clock::now() - totalStart;
    std::cout << "Total iterations: " << iter << " in " 
              << std::chrono::duration<double>(totalTime).count() << " seconds\n";
    return 0;
}
