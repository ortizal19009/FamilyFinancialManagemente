import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule } from '@angular/router';
import { ApiService } from '../../services/api.service';
import { AuthService } from '../../services/auth.service';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [CommonModule, RouterModule],
  templateUrl: './dashboard.html',
  styleUrl: './dashboard.scss'
})
export class DashboardComponent implements OnInit {
  private apiService = inject(ApiService);
  private authService = inject(AuthService);

  currentUser = this.authService.currentUser;
  stats = {
    availableBalance: 0,
    totalDebt: 0,
    monthlyExpenses: 0,
    totalAssets: 0,
    investmentsCurrentValue: 0,
    investmentsInvestedAmount: 0
  };

  recentExpenses: any[] = [];

  ngOnInit() {
    this.loadDashboardSummary();
  }

  loadDashboardSummary() {
    this.apiService.getDashboardSummary().subscribe(summary => {
      this.stats = summary.stats;
      this.recentExpenses = summary.recentExpenses;
    });
  }
}
