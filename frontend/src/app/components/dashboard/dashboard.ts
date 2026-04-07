import { Component, HostListener, OnDestroy, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { NavigationEnd, Router, RouterModule } from '@angular/router';
import { filter, Subscription } from 'rxjs';
import { ApiService } from '../../services/api.service';
import { AuthService } from '../../services/auth.service';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [CommonModule, RouterModule],
  templateUrl: './dashboard.html',
  styleUrl: './dashboard.scss'
})
export class DashboardComponent implements OnInit, OnDestroy {
  private apiService = inject(ApiService);
  private authService = inject(AuthService);
  private router = inject(Router);
  private subscriptions = new Subscription();

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
    this.subscriptions.add(
      this.router.events
        .pipe(filter((event) => event instanceof NavigationEnd))
        .subscribe((event) => {
          const navigation = event as NavigationEnd;
          if (navigation.urlAfterRedirects.startsWith('/dashboard')) {
            this.loadDashboardSummary();
          }
        })
    );
  }

  ngOnDestroy() {
    this.subscriptions.unsubscribe();
  }

  @HostListener('window:focus')
  onWindowFocus() {
    this.loadDashboardSummary();
  }

  @HostListener('document:visibilitychange')
  onVisibilityChange() {
    if (document.visibilityState === 'visible') {
      this.loadDashboardSummary();
    }
  }

  loadDashboardSummary() {
    this.apiService.getDashboardSummary().subscribe(summary => {
      this.stats = summary.stats;
      this.recentExpenses = summary.recentExpenses;
    });
  }
}
